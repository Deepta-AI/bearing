// Package files stores tenant files and serves them over HTTP.
package files

import (
	"crypto/rand"
	"encoding/hex"
	"sync"
)

// File is one uploaded file.
type File struct {
	ID          string
	TenantID    string
	Name        string
	ContentType string
	Data        []byte
}

// Store keeps files in memory (the blob store is behind this interface in
// production; see deploy/k8s).
type Store struct {
	mu    sync.RWMutex
	files map[string]File
}

// NewStore returns an empty store.
func NewStore() *Store { return &Store{files: map[string]File{}} }

// Put stores f under a new random id and returns the id.
func (s *Store) Put(f File) string {
	var b [16]byte
	rand.Read(b[:])
	f.ID = hex.EncodeToString(b[:])
	s.mu.Lock()
	s.files[f.ID] = f
	s.mu.Unlock()
	return f.ID
}

// Get returns the file with id.
func (s *Store) Get(id string) (File, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	f, ok := s.files[id]
	return f, ok
}

// ListByTenant returns the tenant's files.
func (s *Store) ListByTenant(tenant string) []File {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var out []File
	for _, f := range s.files {
		if f.TenantID == tenant {
			out = append(out, f)
		}
	}
	return out
}
