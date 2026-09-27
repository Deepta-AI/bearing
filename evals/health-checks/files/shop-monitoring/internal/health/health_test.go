package health

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func ok(context.Context) error   { return nil }
func down(context.Context) error { return errors.New("down") }

func TestReadyz(t *testing.T) {
	cases := []struct {
		name   string
		checks []Check
		want   int
	}{
		{"all ok", []Check{{Name: "postgres", Required: true, Timeout: time.Second, Probe: ok}}, 200},
		{"optional down", []Check{{Name: "redis", Timeout: time.Second, Probe: down}}, 200},
		{"required down", []Check{{Name: "postgres", Required: true, Timeout: time.Second, Probe: down}}, 503},
	}
	for _, c := range cases {
		rec := httptest.NewRecorder()
		(&Handler{Version: "t", Checks: c.checks}).Readyz(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
		if rec.Code != c.want {
			t.Errorf("%s: code %d, want %d", c.name, rec.Code, c.want)
		}
	}
}
