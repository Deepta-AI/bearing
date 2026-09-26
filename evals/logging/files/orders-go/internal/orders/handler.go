package orders

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
)

type Handler struct {
	Svc    *Service
	Notify Notifier
}

type createReq struct {
	Email string `json:"email"`
	Phone string `json:"phone"`
	SKU   string `json:"sku"`
	Qty   int    `json:"qty"`
}

func (h Handler) Create(w http.ResponseWriter, r *http.Request) {
	var req createReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	log.Printf("creating order for %s (%s): %+v", req.Email, req.Phone, req)
	o, err := h.Svc.Create(req.Email, req.SKU, req.Qty)
	if err != nil {
		log.Printf("create failed: %v", err)
		status := http.StatusUnprocessableEntity
		if errors.Is(err, ErrBlocked) {
			status = http.StatusForbidden
		}
		http.Error(w, err.Error(), status)
		return
	}
	fmt.Println("order created", o.ID)
	go func() {
		if err := h.Notify.OrderPlaced(o); err != nil {
			log.Printf("confirmation failed: %v", err)
		}
	}()
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(o)
}

func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	o, ok := h.Svc.Get(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	_ = json.NewEncoder(w).Encode(o)
}

// List serves GET /orders?email=..., the support desk's customer lookup.
func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	email := r.URL.Query().Get("email")
	if email == "" {
		http.Error(w, "email is required", http.StatusBadRequest)
		return
	}
	_ = json.NewEncoder(w).Encode(h.Svc.ListByEmail(email))
}

// Export streams every order as NDJSON for the nightly finance pull. It
// flushes per order so the client sees progress on a large export.
func (h Handler) Export(w http.ResponseWriter, r *http.Request) {
	f, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/x-ndjson")
	enc := json.NewEncoder(w)
	for _, o := range h.Svc.All() {
		_ = enc.Encode(o)
		f.Flush()
	}
}
