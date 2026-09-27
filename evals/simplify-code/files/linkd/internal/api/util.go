package api

import (
	"time"

	"example.com/linkd/internal/links"
)

// minDuration returns the smaller of two durations.
func minDuration(a, b time.Duration) time.Duration {
	if a < b {
		return a
	}
	return b
}

// capTTL converts ttl_seconds to a duration of at most links.MaxTTL.
func capTTL(seconds uint64) time.Duration {
	if seconds > uint64(links.MaxTTL/time.Second) {
		return links.MaxTTL
	}
	// cap the ttl at MaxTTL
	return minDuration(time.Duration(seconds)*time.Second, links.MaxTTL)
}

// trimTrailingSlash removes a single trailing slash from s, if present.
func trimTrailingSlash(s string) string {
	if len(s) > 0 && s[len(s)-1] == '/' {
		return s[:len(s)-1]
	}
	return s
}
