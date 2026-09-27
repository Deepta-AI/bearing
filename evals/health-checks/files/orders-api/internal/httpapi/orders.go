package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"example.com/orders-api/internal/orders"
)

type createReq struct {
	Lines []orders.Line `json:"lines"`
}

func createOrder(d Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req createReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.Lines) == 0 {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		o, err := d.Orders.Create(r.Context(), subject(r), req.Lines)
		if err != nil {
			d.Log.Error("create order", "err", err)
			http.Error(w, "could not create order", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusCreated, o)
	}
}

func getOrder(d Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
		if err != nil {
			http.Error(w, "bad id", http.StatusBadRequest)
			return
		}
		o, err := d.Orders.Get(r.Context(), id)
		if err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		writeJSON(w, http.StatusOK, o)
	}
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func requestLog(log *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Info("request", "method", r.Method, "path", r.URL.Path, "ms", time.Since(start).Milliseconds())
	})
}
