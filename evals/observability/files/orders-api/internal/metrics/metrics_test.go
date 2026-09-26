package metrics

import (
	"strings"
	"testing"
	"time"
)

func TestHistogramText(t *testing.T) {
	r := NewRegistry()
	r.Observe("POST", "/checkout", 201, 80*time.Millisecond)
	r.Observe("POST", "/checkout", 201, 2*time.Second)
	out := r.Text()
	for _, want := range []string{
		`http_server_request_duration_seconds_bucket{http_request_method="POST",http_route="/checkout",http_response_status_code="201",le="0.1"} 1`,
		`http_server_request_duration_seconds_bucket{http_request_method="POST",http_route="/checkout",http_response_status_code="201",le="+Inf"} 2`,
		`http_server_request_duration_seconds_count{http_request_method="POST",http_route="/checkout",http_response_status_code="201"} 2`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %s in\n%s", want, out)
		}
	}
}
