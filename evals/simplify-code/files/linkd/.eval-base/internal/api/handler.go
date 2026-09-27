package api

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/url"
	"time"

	"example.com/linkd/internal/links"
)

// Handler serves the link API.
type Handler struct {
	store *links.Store
	now   func() time.Time
}

// New returns a Handler over store; now is the clock (time.Now in main).
func New(store *links.Store, now func() time.Time) *Handler {
	return &Handler{store: store, now: now}
}

// Routes returns the API's routes.
func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /links", h.create)
	mux.HandleFunc("GET /{code}", h.get)
	return mux
}

type createRequest struct {
	URL string `json:"url"`
}

type createResponse struct {
	Code string `json:"code"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var req createRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}
	u, err := url.Parse(req.URL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		http.Error(w, "url must be an absolute http or https URL", http.StatusBadRequest)
		return
	}
	now := h.now()
	link := links.Link{Code: links.Code(req.URL, now), URL: req.URL, Created: now.UTC()}
	if err := h.store.Put(link); err != nil {
		log.Printf("put %s: %v", link.Code, err)
		http.Error(w, "could not save link", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(createResponse{Code: link.Code})
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	link, err := h.store.Get(r.PathValue("code"))
	if errors.Is(err, links.ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		http.Error(w, "lookup failed", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, link.URL, http.StatusFound)
}
