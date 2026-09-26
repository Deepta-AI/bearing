package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"sync"
)

// Principal is the logged-in staff member.
type Principal struct {
	UserID   string
	ClinicID string
	Role     string // admin, doctor or receptionist
}

type ctxKey struct{}

// Sessions maps a session id (the sid cookie) to the principal.
type Sessions struct {
	mu   sync.Mutex
	byID map[string]Principal
}

func NewSessions() *Sessions { return &Sessions{byID: map[string]Principal{}} }

func (s *Sessions) Create(p Principal) string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	id := hex.EncodeToString(b)
	s.mu.Lock()
	s.byID[id] = p
	s.mu.Unlock()
	return id
}

func (s *Sessions) Lookup(id string) (Principal, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.byID[id]
	return p, ok
}

// EndUser ends every web session of the given user.
func (s *Sessions) EndUser(userID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for id, p := range s.byID {
		if p.UserID == userID {
			delete(s.byID, id)
		}
	}
}

// RequireLogin rejects requests without a valid sid cookie and puts the
// principal on the context.
func (s *Sessions) RequireLogin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie("sid")
		if err != nil {
			http.Error(w, "unauthorised", http.StatusUnauthorized)
			return
		}
		p, ok := s.Lookup(c.Value)
		if !ok {
			http.Error(w, "unauthorised", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, p)))
	})
}

// FromContext returns the principal set by RequireLogin.
func FromContext(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(ctxKey{}).(Principal)
	return p, ok
}
