package webhooks

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"example.com/billing/internal/invoices"
)

type fakeStore struct {
	byRef map[string]invoices.Invoice
	paid  []int64
}

func (f *fakeStore) FindByExternalRef(_ context.Context, ref string) (invoices.Invoice, error) {
	inv, ok := f.byRef[ref]
	if !ok {
		return invoices.Invoice{}, invoices.ErrNotFound
	}
	return inv, nil
}

func (f *fakeStore) MarkPaid(_ context.Context, id int64, _ time.Time) error {
	f.paid = append(f.paid, id)
	return nil
}

func TestPaidHandler(t *testing.T) {
	cases := []struct {
		name     string
		body     string
		wantCode int
		wantPaid int
	}{
		{"known reference", `{"reference":"pl_123"}`, http.StatusNoContent, 1},
		{"unknown reference", `{"reference":"pl_999"}`, http.StatusNoContent, 0},
		{"no reference", `{}`, http.StatusBadRequest, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			st := &fakeStore{byRef: map[string]invoices.Invoice{"pl_123": {ID: 7}}}
			h := PaidHandler{Store: st, Now: time.Now}
			rec := httptest.NewRecorder()
			h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/webhooks/payment-paid", strings.NewReader(tc.body)))
			if rec.Code != tc.wantCode {
				t.Fatalf("code = %d, want %d", rec.Code, tc.wantCode)
			}
			if len(st.paid) != tc.wantPaid {
				t.Fatalf("paid = %v, want %d", st.paid, tc.wantPaid)
			}
		})
	}
}
