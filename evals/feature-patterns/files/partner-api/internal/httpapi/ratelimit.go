package httpapi

import (
	"net/http"
	"sync"
	"time"
)

// loginLimiter allows `perMinute` token requests per client per minute to
// slow down secret guessing.
type loginLimiter struct {
	mu        sync.Mutex
	perMinute int
	window    time.Time
	counts    map[string]int
}

func newLoginLimiter(perMinute int) *loginLimiter {
	return &loginLimiter{perMinute: perMinute, counts: map[string]int{}}
}

func (l *loginLimiter) wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		now := time.Now().Truncate(time.Minute)
		l.mu.Lock()
		if !now.Equal(l.window) {
			l.window = now
			l.counts = map[string]int{}
		}
		l.counts[r.RemoteAddr]++
		n := l.counts[r.RemoteAddr]
		l.mu.Unlock()
		if n > l.perMinute {
			http.Error(w, "too many requests", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}
