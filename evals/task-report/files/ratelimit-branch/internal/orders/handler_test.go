package orders

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetOrder(t *testing.T) {
	cases := []struct {
		path string
		want int
	}{
		{"/v1/orders", http.StatusOK},
		{"/v1/orders/ord_1001", http.StatusOK},
		{"/v1/orders/ord_9999", http.StatusNotFound},
	}
	h := Routes()
	for _, c := range cases {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, c.path, nil))
		if rec.Code != c.want {
			t.Errorf("%s: got %d, want %d", c.path, rec.Code, c.want)
		}
	}
}
