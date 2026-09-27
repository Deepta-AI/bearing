package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPaymentsAndMetrics(t *testing.T) {
	cases := []struct {
		name string
		body string
		want int
	}{
		{"valid", `{"amount_minor":1500,"currency":"INR"}`, http.StatusAccepted},
		{"zero amount", `{"amount_minor":0,"currency":"INR"}`, http.StatusBadRequest},
		{"not json", `nope`, http.StatusBadRequest},
	}
	s := New()
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			s.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/v1/payments", strings.NewReader(tc.body)))
			if rec.Code != tc.want {
				t.Fatalf("got %d, want %d", rec.Code, tc.want)
			}
		})
	}
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	out := rec.Body.String()
	for _, want := range []string{`http_requests_total{code="202"} 1`, `http_requests_total{code="400"} 2`, `provider_requests_total{result="ok"} 1`} {
		if !strings.Contains(out, want) {
			t.Errorf("metrics missing %q:\n%s", want, out)
		}
	}
}

func TestHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	New().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("healthz: %d", rec.Code)
	}
}
