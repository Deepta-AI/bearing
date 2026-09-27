package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"

	"example.com/linkd/internal/links"
)

// Handler serves the link API.
type Handler struct {
	// mu serialises access to the store across requests.
	mu      sync.Mutex
	store   *links.Store
	now     func() time.Time
	expirer links.Expirer
}

// New returns a Handler over store; now is the clock (time.Now in main).
func New(store *links.Store, now func() time.Time) *Handler {
	// create the expirer with default options
	expirer := links.NewExpirer(now, links.ExpirerOptions{})
	// return the handler
	return &Handler{store: store, now: now, expirer: expirer}
}

// Routes returns the API's routes.
func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /links", h.create)
	mux.HandleFunc("GET /{code...}", h.get)
	return mux
}

type createRequest struct {
	URL        string `json:"url"`
	TTLSeconds uint64 `json:"ttl_seconds"`
}

type createResponse struct {
	Code      string     `json:"code"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
}

// validateURL checks that raw is an absolute http or https URL.
// The web form already enforces this with type=url; this double-checks it.
func validateURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return fmt.Errorf("url must be an absolute http or https URL")
	}
	return nil
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	// recover from panics and re-panic so the server can handle them
	defer func() {
		if rec := recover(); rec != nil {
			panic(rec)
		}
	}()
	log.Println("create: start")
	var req createRequest
	// decode the request body
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&req); err != nil {
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}
	// validate the URL
	if err := validateURL(req.URL); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	// make sure the ttl is not negative
	if req.TTLSeconds < 0 {
		http.Error(w, "ttl_seconds must not be negative", http.StatusBadRequest)
		return
	}
	now := h.now()
	// build the link
	link := links.Link{Code: links.Code(req.URL, now), URL: req.URL, Created: now.UTC()}
	// set the expiry if a ttl was given, capped at MaxTTL
	if req.TTLSeconds > 0 {
		link.ExpiresAt = now.Add(capTTL(req.TTLSeconds)).UTC()
	}
	// save the link
	h.mu.Lock()
	err := h.store.Put(link)
	h.mu.Unlock()
	if err != nil {
		log.Printf("put %s: %v", link.Code, err)
		http.Error(w, "could not save link", http.StatusInternalServerError)
		return
	}
	// build the response
	resp := createResponse{Code: link.Code}
	if !link.ExpiresAt.IsZero() {
		resp.ExpiresAt = &link.ExpiresAt
	}
	// write the response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(resp)
	log.Println("create: done")
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	log.Println("get: start")
	// remove the trailing slash from the code
	code := trimTrailingSlash(r.PathValue("code"))
	// look up the link
	h.mu.Lock()
	link, err := h.store.Get(code)
	h.mu.Unlock()
	if errors.Is(err, links.ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		http.Error(w, "lookup failed", http.StatusInternalServerError)
		return
	}
	// check whether the link has expired
	if h.expirer.Expired(link) {
		http.Error(w, "link expired", http.StatusGone)
		return
	}
	// redirect to the URL
	http.Redirect(w, r, link.URL, http.StatusFound)
	log.Println("get: done")
}
