// Package customers registers customers one at a time or from a CSV import.
package customers

import (
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"strings"

	"example.com/orders/internal/store"
)

type Service struct {
	Store *store.Store
}

func (s *Service) Register(email, name string) (store.Customer, error) {
	if !strings.Contains(email, "@") {
		return store.Customer{}, fmt.Errorf("customers: invalid email %q", email)
	}
	return s.Store.Insert(email, name)
}

// ImportResult counts what an import did; duplicates are skipped, not errors.
type ImportResult struct {
	Imported   int
	Duplicates int
}

// Import reads "email,name" rows and registers each one.
func (s *Service) Import(r io.Reader) (ImportResult, error) {
	var res ImportResult
	rows, err := csv.NewReader(r).ReadAll()
	if err != nil {
		return res, err
	}
	for _, row := range rows {
		if len(row) != 2 {
			return res, fmt.Errorf("customers: bad row %q", row)
		}
		_, err := s.Register(row[0], row[1])
		switch {
		case errors.Is(err, store.ErrDuplicateEmail):
			res.Duplicates++
		case err != nil:
			return res, err
		default:
			res.Imported++
		}
	}
	return res, nil
}
