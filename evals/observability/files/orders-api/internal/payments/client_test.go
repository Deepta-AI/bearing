package payments

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestChargeRetriesOnce503(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if r.Header.Get("Idempotency-Key") != "order-o1" {
			t.Errorf("idempotency key %q", r.Header.Get("Idempotency-Key"))
		}
		w.Write([]byte(`{"charge_id":"ch_1","status":"succeeded"}`))
	}))
	defer srv.Close()

	id, err := New(srv.URL).Charge("o1", 1299)
	if err != nil || id != "ch_1" {
		t.Fatalf("got %q, %v", id, err)
	}
	if calls != 2 {
		t.Fatalf("calls = %d, want 2", calls)
	}
}

func TestChargeDeclined(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusPaymentRequired)
	}))
	defer srv.Close()
	if _, err := New(srv.URL).Charge("o2", 500); !errors.Is(err, ErrDeclined) {
		t.Fatalf("err = %v, want ErrDeclined", err)
	}
}
