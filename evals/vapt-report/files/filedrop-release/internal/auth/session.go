// Package auth signs and checks session cookies and handles login.
package auth

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
)

// Session is the signed-in user and their tenant.
type Session struct {
	UserID   string
	TenantID string
}

// ErrBadSession is returned for a cookie that fails to parse or verify.
var ErrBadSession = errors.New("auth: bad session")

// Signer signs and verifies session cookie values.
type Signer struct{ Key []byte }

func (s Signer) mac(msg string) string {
	m := hmac.New(sha256.New, s.Key)
	m.Write([]byte(msg))
	return hex.EncodeToString(m.Sum(nil))
}

// Sign returns the cookie value for a session: user.tenant.mac
func (s Signer) Sign(sess Session) string {
	msg := sess.UserID + "." + sess.TenantID
	return msg + "." + s.mac(msg)
}

// Parse verifies a cookie value and returns its session.
func (s Signer) Parse(v string) (Session, error) {
	parts := strings.Split(v, ".")
	if len(parts) != 3 {
		return Session{}, ErrBadSession
	}
	msg := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(parts[2]), []byte(s.mac(msg))) {
		return Session{}, ErrBadSession
	}
	return Session{UserID: parts[0], TenantID: parts[1]}, nil
}

type ctxKey struct{}

// Require rejects requests without a valid session cookie and puts the
// session on the request context.
func (s Signer) Require(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie("fd_session")
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		sess, err := s.Parse(c.Value)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, sess)))
	})
}

// From returns the session Require put on the context.
func From(ctx context.Context) Session {
	s, _ := ctx.Value(ctxKey{}).(Session)
	return s
}

// WithSession returns ctx carrying sess (for tests and internal callers).
func WithSession(ctx context.Context, sess Session) context.Context {
	return context.WithValue(ctx, ctxKey{}, sess)
}
