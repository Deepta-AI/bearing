package api

import (
	"encoding/json"
	"net/http"
)

type Address struct {
	ID      string `json:"id"`
	Line1   string `json:"line1"`
	City    string `json:"city"`
	Pincode string `json:"pincode"`
}

var addresses = map[string][]Address{
	"cus_42": {{ID: "adr_1", Line1: "14 MG Road", City: "Bengaluru", Pincode: "560001"}},
}

func Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/customers/{id}/addresses", deprecated(getAddressesV1))
	mux.HandleFunc("GET /v2/customers/{id}/addresses", getAddressesV2)
	return mux
}

// deprecated sends the headers agreed in docs/api/API_LIFECYCLE.md.
func deprecated(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Deprecation", "@1778976000")
		w.Header().Set("Sunset", "Sat, 15 Aug 2026 00:00:00 GMT")
		w.Header().Set("Link", `</v2/customers/`+r.PathValue("id")+`/addresses>; rel="successor-version"`)
		next(w, r)
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

// v1 returns a bare array.
func getAddressesV1(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, addresses[r.PathValue("id")])
}

// v2 wraps the list so it can be paginated.
func getAddressesV2(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"data": addresses[r.PathValue("id")], "next_cursor": nil})
}
