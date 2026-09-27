package webhook

import "sync"

// Store remembers which event ids were accepted.
type Store interface {
	// MarkSeen records id and reports whether it was new.
	MarkSeen(id string) bool
}

// MemoryStore is a Store for one process.
type MemoryStore struct {
	mu   sync.Mutex
	seen map[string]bool
}

func NewMemoryStore() *MemoryStore { return &MemoryStore{seen: map[string]bool{}} }

func (s *MemoryStore) MarkSeen(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.seen[id] {
		return false
	}
	s.seen[id] = true
	return true
}
