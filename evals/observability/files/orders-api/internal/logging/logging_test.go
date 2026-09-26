package logging

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMiddlewareWritesOneLine(t *testing.T) {
	var buf bytes.Buffer
	log := New(&buf, slog.LevelInfo)
	h := Middleware(log, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusCreated)
	}))
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/checkout", nil))

	var line map[string]any
	if err := json.Unmarshal(buf.Bytes(), &line); err != nil {
		t.Fatalf("not one JSON line: %v: %q", err, buf.String())
	}
	if line["msg"] != "request" || line["status"] != float64(201) {
		t.Fatalf("unexpected line %v", line)
	}
	if line["request_id"] == "" {
		t.Fatal("no request_id")
	}
}

func TestHealthzNotLogged(t *testing.T) {
	var buf bytes.Buffer
	h := Middleware(New(&buf, slog.LevelInfo), http.NotFoundHandler())
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/healthz", nil))
	if buf.Len() != 0 {
		t.Fatalf("healthz logged: %q", buf.String())
	}
}
