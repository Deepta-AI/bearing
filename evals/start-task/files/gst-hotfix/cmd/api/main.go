package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"example.com/rates-api/internal/gst"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/gst", func(w http.ResponseWriter, r *http.Request) {
		amount, err1 := strconv.ParseInt(r.URL.Query().Get("amount_paise"), 10, 64)
		bps, err2 := strconv.ParseInt(r.URL.Query().Get("rate_bps"), 10, 64)
		if err1 != nil || err2 != nil || amount < 0 || bps < 0 {
			http.Error(w, `{"error":"bad_request"}`, http.StatusBadRequest)
			return
		}
		tax := gst.Tax(amount, bps)
		cgst, sgst := gst.Split(tax)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]int64{"tax_paise": tax, "cgst_paise": cgst, "sgst_paise": sgst})
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
