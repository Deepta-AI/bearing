package invoices

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/ledgerly/internal/auth"
)

func TestGetIsTenantScoped(t *testing.T) {
	st := NewStore()
	id := st.Add(Invoice{TenantID: "t1", Customer: "Acme Traders", Amount: 125000})
	h := Handler{Store: st}
	r := httptest.NewRequest(http.MethodGet, "/api/v1/invoices/"+id, nil)
	r.SetPathValue("id", id)
	r = r.WithContext(auth.WithTenant(r.Context(), "t2"))
	w := httptest.NewRecorder()
	h.Get(w, r)
	if w.Code != http.StatusNotFound {
		t.Fatalf("other tenant got status %d", w.Code)
	}
}
