package reports

import (
	"encoding/json"
	"errors"
	"net/http"

	"example.com/reportsvc/internal/flags"
)

// Handler serves reports over HTTP.
type Handler struct {
	Store *Store
	Flags *flags.Set
	Audit func(reportID string)
}

// Routes registers the report endpoints on mux.
func (h *Handler) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /reports/{id}", h.get)
}

func (h *Handler) load(w http.ResponseWriter, req *http.Request) (Report, bool) {
	r, err := h.Store.Get(req.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.NotFound(w, req)
		return Report{}, false
	}
	if h.Flags.Enabled(flags.AuditLogV2) && h.Audit != nil {
		h.Audit(r.ID)
	}
	return applyFilters(req, r), true
}

func (h *Handler) get(w http.ResponseWriter, req *http.Request) {
	r, ok := h.load(w, req)
	if !ok {
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(r)
}
