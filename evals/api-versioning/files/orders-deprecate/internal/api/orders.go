package api

import (
	"encoding/json"
	"net/http"
)

type Line struct {
	SKU            string
	Name           string
	Quantity       int
	UnitPricePaise int64
	HSN            string // GST goods classification code
}

type Order struct {
	ID       string
	Status   string
	Currency string
	Lines    []Line
}

type Store map[string]Order

func SampleStore() Store {
	return Store{"ord_1001": {ID: "ord_1001", Status: "shipped", Currency: "INR", Lines: []Line{
		{SKU: "TEA-250", Name: "Assam tea 250 g", Quantity: 2, UnitPricePaise: 34950, HSN: "0902"},
	}}}
}

func Routes(st Store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/orders/{id}", st.getOrderV1)
	mux.HandleFunc("GET /v1/orders/{id}/items", st.getOrderItemsV1)
	mux.HandleFunc("GET /v2/orders/{id}", st.getOrderV2)
	return mux
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func (st Store) find(w http.ResponseWriter, r *http.Request) (Order, bool) {
	o, ok := st[r.PathValue("id")]
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
	}
	return o, ok
}

// v1: order header only; items are a second call.
func (st Store) getOrderV1(w http.ResponseWriter, r *http.Request) {
	o, ok := st.find(w, r)
	if !ok {
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": o.ID, "status": o.Status})
}

// v1 items: price is rupees as a float, quantity is "qty", plus the HSN code.
func (st Store) getOrderItemsV1(w http.ResponseWriter, r *http.Request) {
	o, ok := st.find(w, r)
	if !ok {
		return
	}
	items := []map[string]any{}
	for _, l := range o.Lines {
		items = append(items, map[string]any{
			"sku": l.SKU, "name": l.Name, "qty": l.Quantity,
			"price": float64(l.UnitPricePaise) / 100, "hsn_code": l.HSN,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"order_id": o.ID, "items": items})
}

// v2: order with its lines embedded, money in paise.
func (st Store) getOrderV2(w http.ResponseWriter, r *http.Request) {
	o, ok := st.find(w, r)
	if !ok {
		return
	}
	lines := []map[string]any{}
	for _, l := range o.Lines {
		lines = append(lines, map[string]any{
			"sku": l.SKU, "name": l.Name, "quantity": l.Quantity,
			"unit_price_minor": l.UnitPricePaise,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": o.ID, "status": o.Status, "currency": o.Currency, "lines": lines,
	})
}
