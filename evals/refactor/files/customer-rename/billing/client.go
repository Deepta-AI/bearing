// Package billing holds the paying accounts and charges them.
package billing

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sort"
	"sync"
)

// ErrClientNotFound is returned when no client has the given id.
var ErrClientNotFound = errors.New("client not found")

// Client is one paying account.
type Client struct {
	ID           string `json:"client_id"`
	Name         string `json:"name"`
	Plan         string `json:"plan"`
	Active       bool   `json:"active"`
	MonthlyPaise int64  `json:"monthly_paise"`
}

// Store keeps clients in memory, keyed by id.
type Store struct {
	mu      sync.RWMutex
	clients map[string]Client
}

// NewStore returns a store holding the given clients.
func NewStore(clients []Client) *Store {
	s := &Store{clients: make(map[string]Client, len(clients))}
	for _, c := range clients {
		s.clients[c.ID] = c
	}
	return s
}

// LoadFile reads a JSON array of clients.
func LoadFile(path string) (*Store, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read clients: %w", err)
	}
	var clients []Client
	if err := json.Unmarshal(b, &clients); err != nil {
		return nil, fmt.Errorf("parse clients: %w", err)
	}
	return NewStore(clients), nil
}

// Client returns the client with the given id.
func (s *Store) Client(id string) (Client, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	c, ok := s.clients[id]
	if !ok {
		return Client{}, ErrClientNotFound
	}
	return c, nil
}

// ActiveClients returns the active clients sorted by id.
func (s *Store) ActiveClients() []Client {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var out []Client
	for _, c := range s.clients {
		if c.Active {
			out = append(out, c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}
