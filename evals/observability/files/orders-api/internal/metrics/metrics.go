// Package metrics records the HTTP request duration histogram and serves
// it in the Prometheus text format. Hand-rolled to keep the module free
// of dependencies.
package metrics

import (
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Buckets are the upper bounds, in seconds, of the duration histogram.
var Buckets = []float64{0.05, 0.1, 0.25, 0.5, 1}

type series struct {
	counts []uint64 // one per bucket, cumulative is computed on write
	count  uint64
	sum    float64
}

type key struct{ method, route, status string }

// Registry holds the request duration histogram.
type Registry struct {
	mu sync.Mutex
	m  map[key]*series
}

func NewRegistry() *Registry { return &Registry{m: map[key]*series{}} }

// Observe records one request.
func (r *Registry) Observe(method, route string, status int, d time.Duration) {
	k := key{method, route, fmt.Sprint(status)}
	r.mu.Lock()
	defer r.mu.Unlock()
	s := r.m[k]
	if s == nil {
		s = &series{counts: make([]uint64, len(Buckets))}
		r.m[k] = s
	}
	sec := d.Seconds()
	for i, b := range Buckets {
		if sec <= b {
			s.counts[i]++
			break
		}
	}
	s.count++
	s.sum += sec
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

// Middleware times every request, labelled by the route pattern.
func (r *Registry) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()
		next.ServeHTTP(sw, req)
		route := req.Pattern
		if i := strings.IndexByte(route, ' '); i >= 0 {
			route = route[i+1:]
		}
		r.Observe(req.Method, route, sw.status, time.Since(start))
	})
}

// ServeHTTP writes the histogram and the process CPU counter.
func (r *Registry) ServeHTTP(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprint(w, r.Text())
	var ru syscall.Rusage
	if syscall.Getrusage(syscall.RUSAGE_SELF, &ru) == nil {
		cpu := float64(ru.Utime.Sec+ru.Stime.Sec) + float64(ru.Utime.Usec+ru.Stime.Usec)/1e6
		fmt.Fprintf(w, "# TYPE process_cpu_seconds_total counter\nprocess_cpu_seconds_total %g\n", cpu)
	}
}

// Text renders the histogram in the Prometheus text format.
func (r *Registry) Text() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	keys := make([]key, 0, len(r.m))
	for k := range r.m {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool { return fmt.Sprint(keys[i]) < fmt.Sprint(keys[j]) })
	var b strings.Builder
	b.WriteString("# TYPE http_server_request_duration_seconds histogram\n")
	for _, k := range keys {
		s := r.m[k]
		labels := fmt.Sprintf(`http_request_method=%q,http_route=%q,http_response_status_code=%q`, k.method, k.route, k.status)
		var cum uint64
		for i, le := range Buckets {
			cum += s.counts[i]
			fmt.Fprintf(&b, "http_server_request_duration_seconds_bucket{%s,le=\"%g\"} %d\n", labels, le, cum)
		}
		fmt.Fprintf(&b, "http_server_request_duration_seconds_bucket{%s,le=\"+Inf\"} %d\n", labels, s.count)
		fmt.Fprintf(&b, "http_server_request_duration_seconds_sum{%s} %g\n", labels, s.sum)
		fmt.Fprintf(&b, "http_server_request_duration_seconds_count{%s} %d\n", labels, s.count)
	}
	return b.String()
}
