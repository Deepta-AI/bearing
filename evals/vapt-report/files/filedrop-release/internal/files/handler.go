package files

import (
	"encoding/json"
	"fmt"
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
	mux.Handle("GET /files/{id}/download", s.Require(http.HandlerFunc(h.download)))
	mux.Handle("GET /files/{id}/preview", s.Require(http.HandlerFunc(h.preview)))
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

func (h Handler) download(w http.ResponseWriter, r *http.Request) {
	f, ok := h.Store.Get(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", f.Name))
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Write(f.Data)
}

func (h Handler) preview(w http.ResponseWriter, r *http.Request) {
	sess := auth.From(r.Context())
	f, ok := h.Store.Get(r.PathValue("id"))
	if !ok || f.TenantID != sess.TenantID {
		http.NotFound(w, r)
		return
	}
	img, err := h.Preview(f)
	if err != nil {
		http.Error(w, fmt.Sprintf("preview failed: %v", err), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Write(img)
}
