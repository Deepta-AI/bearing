// Package share hands out public links to single files.
package share

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/http"
	"sync"
	"time"
)

// ErrNotFound is returned for an unknown token.
var ErrNotFound = errors.New("share: link not found")

type link struct {
	FileID    string
	TenantID  string
	CreatedAt time.Time
}

// Links stores share links in memory.
type Links struct {
	mu    sync.Mutex
	links map[string]link
	Now   func() time.Time
}

// NewLinks returns an empty link store.
func NewLinks() *Links { return &Links{links: map[string]link{}, Now: time.Now} }

// Create returns a new 128-bit token for the tenant's file.
func (l *Links) Create(fileID, tenantID string) string {
	var b [16]byte
	rand.Read(b[:])
	tok := hex.EncodeToString(b[:])
	l.mu.Lock()
	l.links[tok] = link{FileID: fileID, TenantID: tenantID, CreatedAt: l.Now()}
	l.mu.Unlock()
	return tok
}

// Resolve returns the file id for a token.
func (l *Links) Resolve(tok string) (string, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	k, ok := l.links[tok]
	if !ok {
		return "", ErrNotFound
	}
	return k.FileID, nil
}

// Serve handles GET /s/{token}: no session needed, the token is the grant.
func (l *Links) Serve(get func(id string) ([]byte, string, bool)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, err := l.Resolve(r.PathValue("token"))
		if err != nil {
			http.NotFound(w, r)
			return
		}
		data, name, ok := get(id)
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", "attachment; filename=\""+name+"\"")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Write(data)
	})
}
