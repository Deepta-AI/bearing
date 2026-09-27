package reports

import (
	"errors"
	"sort"
)

// Report is a saved report.
type Report struct {
	ID        string
	AccountID string
	Title     string
	Columns   []string
	Rows      [][]string
}

// ErrNotFound is returned for an unknown report.
var ErrNotFound = errors.New("report not found")

// Store is an in-memory report store.
type Store struct {
	byID map[string]Report
}

// NewStore returns a store holding reports.
func NewStore(reports ...Report) *Store {
	s := &Store{byID: map[string]Report{}}
	for _, r := range reports {
		s.byID[r.ID] = r
	}
	return s
}

// Get returns one report.
func (s *Store) Get(id string) (Report, error) {
	r, ok := s.byID[id]
	if !ok {
		return Report{}, ErrNotFound
	}
	return r, nil
}

// ByAccount returns an account's reports ordered by id.
func (s *Store) ByAccount(accountID string) []Report {
	var out []Report
	for _, r := range s.byID {
		if r.AccountID == accountID {
			out = append(out, r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// All returns every report ordered by id.
func (s *Store) All() []Report {
	var out []Report
	for _, r := range s.byID {
		out = append(out, r)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}
