package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Metrics records the RED signals (rate, errors, duration) per route pattern
// and status, the minimum every service exposes on /metrics. Labels are the
// mux pattern, never the raw path, so cardinality stays bounded.
type Metrics struct {
	requests *prometheus.CounterVec
	duration *prometheus.HistogramVec
	inFlight prometheus.Gauge
}

// NewMetrics registers the request metrics on reg and returns the middleware
// holder. Pass prometheus.DefaultRegisterer in main, a fresh registry in tests.
func NewMetrics(reg prometheus.Registerer, namespace string) *Metrics {
	m := &Metrics{
		requests: prometheus.NewCounterVec(prometheus.CounterOpts{
			Namespace: namespace, Subsystem: "http", Name: "requests_total",
			Help: "HTTP requests by method, route pattern and status code.",
		}, []string{"method", "route", "status"}),
		duration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Namespace: namespace, Subsystem: "http", Name: "request_duration_seconds",
			Help:    "HTTP request latency by method and route pattern.",
			Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
		}, []string{"method", "route"}),
		inFlight: prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: namespace, Subsystem: "http", Name: "requests_in_flight",
			Help: "HTTP requests currently being served.",
		}),
	}
	reg.MustRegister(m.requests, m.duration, m.inFlight)
	return m
}

// Handler wraps next and records one observation per request.
func (m *Metrics) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		m.inFlight.Inc()
		defer m.inFlight.Dec()
		sw := &StatusWriter{ResponseWriter: w, Status: http.StatusOK}
		next.ServeHTTP(sw, r)
		route := r.Pattern // set by net/http 1.22+ once the mux matched; "" for 404s
		if route == "" {
			route = "unmatched"
		}
		m.requests.WithLabelValues(r.Method, route, strconv.Itoa(sw.Status)).Inc()
		m.duration.WithLabelValues(r.Method, route).Observe(time.Since(start).Seconds())
	})
}

// StatusWriter remembers the status a handler wrote so middleware can log and
// count it. Handlers that never call WriteHeader wrote 200.
type StatusWriter struct {
	http.ResponseWriter
	Status int
}

// WriteHeader records the status, then writes it.
func (s *StatusWriter) WriteHeader(code int) {
	s.Status = code
	s.ResponseWriter.WriteHeader(code)
}

// Unwrap lets http.ResponseController reach the underlying writer.
func (s *StatusWriter) Unwrap() http.ResponseWriter { return s.ResponseWriter }
