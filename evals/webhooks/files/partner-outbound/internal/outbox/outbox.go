// Package outbox holds domain events written with the change that caused them.
package outbox

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

type Event struct {
	ID        string
	Type      string // order.shipped, order.cancelled
	Payload   json.RawMessage
	CreatedAt time.Time
}

// Store is the outbox_events table. Memory is the test implementation.
type Store interface {
	Add(typ string, payload any) (Event, error)
	Pending(limit int) ([]Event, error)
	MarkProcessed(id string) error
}

type Memory struct {
	mu        sync.Mutex
	seq       int
	events    []Event
	processed map[string]bool
	Now       func() time.Time
}

func NewMemory() *Memory {
	return &Memory{processed: map[string]bool{}, Now: time.Now}
}

func (m *Memory) Add(typ string, payload any) (Event, error) {
	b, err := json.Marshal(payload)
	if err != nil {
		return Event{}, err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seq++
	ev := Event{ID: fmt.Sprintf("evt_%08d", m.seq), Type: typ, Payload: b, CreatedAt: m.Now().UTC()}
	m.events = append(m.events, ev)
	return ev, nil
}

func (m *Memory) Pending(limit int) ([]Event, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Event
	for _, ev := range m.events {
		if !m.processed[ev.ID] && len(out) < limit {
			out = append(out, ev)
		}
	}
	return out, nil
}

func (m *Memory) MarkProcessed(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.processed[id] = true
	return nil
}
