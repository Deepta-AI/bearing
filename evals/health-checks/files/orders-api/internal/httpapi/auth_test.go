package httpapi

import (
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOrdersNeedAToken(t *testing.T) {
	h := NewRouter(Deps{
		Log:    slog.New(slog.NewTextHandler(io.Discard, nil)),
		Verify: func(string) (string, error) { return "", errors.New("bad token") },
	})
	for _, path := range []string{"/orders/1"} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("GET %s without a token = %d, want 401", path, rec.Code)
		}
	}
}
