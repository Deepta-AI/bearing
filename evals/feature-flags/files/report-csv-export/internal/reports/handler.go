package reports

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"example.com/reportsvc/internal/flags"
)

// Handler serves reports over HTTP.
type Handler struct {
	Store *Store
	Flags *flags.Set
	Audit func(reportID string)
}

// reportJSON is the JSON shape of GET /reports/{id}: the report and links
// the web app renders as buttons.
type reportJSON struct {
	Report
	Links map[string]string `json:"links,omitempty"`
}

// Routes registers the report endpoints on mux.
func (h *Handler) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /reports/{id}", h.get)
	mux.HandleFunc("GET /reports/{id}/export.csv", h.exportCSV)
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
	out := reportJSON{Report: r, Links: map[string]string{"csv": "/reports/" + r.ID + "/export.csv"}}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(out)
}

// exportCSV serves the report as a CSV download.
// TODO(REP-231): put behind a csv_export flag before release.
func (h *Handler) exportCSV(w http.ResponseWriter, req *http.Request) {
	r, ok := h.load(w, req)
	if !ok {
		return
	}
	body, err := BuildCSV(r)
	if err != nil {
		slog.Error("export csv", "report", r.ID, "err", err)
		http.Error(w, "export failed", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", `attachment; filename="`+r.ID+`.csv"`)
	_, _ = w.Write(body)
}
