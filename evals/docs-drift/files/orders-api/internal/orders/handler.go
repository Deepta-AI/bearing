package orders

import (
	"encoding/json"
	"net/http"

	"example.com/orders-api/internal/db"
)

// CreateHandler decodes the body and writes it straight to the store.
func CreateHandler(s *db.Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var o db.Order
		if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		if err := s.Insert(o); err != nil {
			http.Error(w, "insert failed", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusCreated)
	})
}

func ListHandler(s *db.Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		list, _ := s.List()
		_ = json.NewEncoder(w).Encode(list)
	})
}
