// Package store holds shipments. The in-memory store backs tests and local
// runs; production uses the Postgres store in the platform repository.
package store

import "sync"

type Carrier struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

type Shipment struct {
	ID      string  `json:"id"`
	Status  string  `json:"status"`
	Carrier Carrier `json:"carrier"`
}

type Memory struct {
	mu   sync.Mutex
	rows []Shipment
}

func NewMemory(rows ...Shipment) *Memory { return &Memory{rows: rows} }

// List returns up to limit shipments, filtered by status when status is set.
func (m *Memory) List(status string, limit int) []Shipment {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Shipment{}
	for _, s := range m.rows {
		if status != "" && s.Status != status {
			continue
		}
		if len(out) == limit {
			break
		}
		out = append(out, s)
	}
	return out
}

func (m *Memory) Get(id string) (Shipment, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, s := range m.rows {
		if s.ID == id {
			return s, true
		}
	}
	return Shipment{}, false
}
