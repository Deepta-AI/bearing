package links

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sort"
	"sync"
	"time"
)

// ErrNotFound is returned by Get for an unknown code.
var ErrNotFound = errors.New("link not found")

// Link is one short link as stored in the data file.
type Link struct {
	Code    string    `json:"code"`
	URL     string    `json:"url"`
	Created time.Time `json:"created"`
}

// Store keeps links in memory and writes the whole set to one JSON file on
// every change. An empty path keeps them in memory only (tests).
type Store struct {
	mu    sync.Mutex
	path  string
	links map[string]Link
}

// Open loads the store from path; a missing file is an empty store.
func Open(path string) (*Store, error) {
	s := &Store{path: path, links: map[string]Link{}}
	if path == "" {
		return s, nil
	}
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read links: %w", err)
	}
	var list []Link
	if err := json.Unmarshal(b, &list); err != nil {
		return nil, fmt.Errorf("parse links: %w", err)
	}
	for _, l := range list {
		s.links[l.Code] = l
	}
	return s, nil
}

// Put stores l and writes the file.
func (s *Store) Put(l Link) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.links[l.Code] = l
	return s.save()
}

// Get returns the link for code, or ErrNotFound.
func (s *Store) Get(code string) (Link, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	l, ok := s.links[code]
	if !ok {
		return Link{}, ErrNotFound
	}
	return l, nil
}

func (s *Store) sorted() []Link {
	list := make([]Link, 0, len(s.links))
	for _, l := range s.links {
		list = append(list, l)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].Code < list[j].Code })
	return list
}

func (s *Store) save() error {
	if s.path == "" {
		return nil
	}
	b, err := json.MarshalIndent(s.sorted(), "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(s.path, b, 0o644); err != nil {
		return fmt.Errorf("write links: %w", err)
	}
	return nil
}
