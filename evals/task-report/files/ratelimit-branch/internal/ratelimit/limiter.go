// Package ratelimit limits requests per API key in fixed one minute windows.
package ratelimit

import (
	"net/http"
	"strconv"
	"sync"
	"time"
)

type window struct {
	start time.Time
	count int
}

// Limiter allows PerMinute requests per key in each one minute window.
type Limiter struct {
	perMinute int
	now       func() time.Time

	mu      sync.Mutex
	windows map[string]*window
}

// New returns a limiter allowing perMinute requests per key each minute.
func New(perMinute int) *Limiter {
	return &Limiter{perMinute: perMinute, now: time.Now, windows: map[string]*window{}}
}

// Allow records one request for key. It reports whether the request is within
// the limit and when the current window resets.
func (l *Limiter) Allow(key string) (bool, time.Time) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	start := now.Truncate(time.Minute)
	w := l.windows[key]
	if w == nil || !w.start.Equal(start) {
		w = &window{start: start}
		l.windows[key] = w
	}
	reset := start.Add(time.Minute)
	if w.count >= l.perMinute {
		return false, reset
	}
	w.count++
	return true, reset
}

// Middleware rejects requests over the limit with 429 and a Retry-After header.
func (l *Limiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("X-API-Key")
		if key == "" {
			next.ServeHTTP(w, r)
			return
		}
		ok, reset := l.Allow(key)
		if !ok {
			w.Header().Set("Retry-After", strconv.FormatInt(reset.Sub(l.now()).Milliseconds(), 10))
			http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}
