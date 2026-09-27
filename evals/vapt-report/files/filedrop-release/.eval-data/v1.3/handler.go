package files

import (
	"encoding/json"
	"io"
	"net/http"

	"example.com/filedrop/internal/auth"
)

// Handler serves the /files routes.
type Handler struct {
	Store   *Store
	Preview func(File) ([]byte, error)
}

// Register adds the routes to mux behind the session check.
func (h Handler) Register(mux *http.ServeMux, s auth.Signer) {
	mux.Handle("GET /files", s.Require(http.HandlerFunc(h.list)))
	mux.Handle("POST /files", s.Require(http.HandlerFunc(h.upload)))
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	sess := auth.From(r.Context())
	type item struct{ ID, Name string }
	var out []item
	for _, f := range h.Store.ListByTenant(sess.TenantID) {
		out = append(out, item{f.ID, f.Name})
	}
	json.NewEncoder(w).Encode(out)
}

func (h Handler) upload(w http.ResponseWriter, r *http.Request) {
	sess := auth.From(r.Context())
	data, err := io.ReadAll(io.LimitReader(r.Body, 25<<20))
	if err != nil {
		http.Error(w, "bad upload", http.StatusBadRequest)
		return
	}
	id := h.Store.Put(File{TenantID: sess.TenantID, Name: r.URL.Query().Get("name"),
		ContentType: r.Header.Get("Content-Type"), Data: data})
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"id": id})
}
