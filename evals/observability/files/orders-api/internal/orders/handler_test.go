package orders

import (
	"bytes"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeCharger struct{ err error }

func (f fakeCharger) Charge(string, int64) (string, error) { return "ch_1", f.err }

func newMux(c Charger, logOut io.Writer) *http.ServeMux {
	mux := http.NewServeMux()
	h := &Handler{Log: slog.New(slog.NewJSONHandler(logOut, nil)), Store: NewStore(), Payments: c}
	h.Register(mux)
	return mux
}

func TestCheckoutCreatesOrder(t *testing.T) {
	mux := newMux(fakeCharger{}, io.Discard)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("POST", "/checkout",
		strings.NewReader(`{"customer_id":"c1","amount_cents":1299}`)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
}

func TestCheckoutProviderDownIs502(t *testing.T) {
	var logs bytes.Buffer
	mux := newMux(fakeCharger{err: errors.New("timeout")}, &logs)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("POST", "/checkout",
		strings.NewReader(`{"customer_id":"c1","amount_cents":1299}`)))
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("status %d", rec.Code)
	}
	if !strings.Contains(logs.String(), "checkout failed") {
		t.Fatalf("no failure log: %q", logs.String())
	}
}

func TestGetUnknownOrderIs404(t *testing.T) {
	mux := newMux(fakeCharger{}, io.Discard)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/orders/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status %d", rec.Code)
	}
}
