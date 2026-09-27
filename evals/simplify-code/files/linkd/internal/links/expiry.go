package links

import "time"

// MaxTTL is the maximum time to live for a link.
const MaxTTL = 30 * 24 * time.Hour

// Expirer decides whether links have expired.
type Expirer interface {
	// Expired reports whether the link has expired.
	Expired(l Link) bool
	// Remaining returns how long the link has left before it expires.
	Remaining(l Link) time.Duration
}

// ExpirerOptions configures an Expirer.
type ExpirerOptions struct {
	// GracePeriod is extra time after ExpiresAt during which the link still works.
	GracePeriod time.Duration
	// OnExpire, when set, is called each time a link is found to be expired.
	OnExpire func(Link)
}

// clockExpirer is the default Expirer implementation.
type clockExpirer struct {
	now  func() time.Time
	opts ExpirerOptions
}

// NewExpirer creates a new Expirer.
func NewExpirer(now func() time.Time, opts ExpirerOptions) Expirer {
	// default to the system clock
	if now == nil {
		now = time.Now
	}
	// return the expirer
	return &clockExpirer{now: now, opts: opts}
}

// Expired reports whether the link has expired.
func (e *clockExpirer) Expired(l Link) bool {
	// guard against a nil receiver
	if e == nil {
		return false
	}
	// links without an expiry never expire
	if l.ExpiresAt.IsZero() {
		return false
	}
	// check whether the expiry (plus grace) has passed
	expired := !e.now().Before(l.ExpiresAt.Add(e.opts.GracePeriod))
	// notify the callback if one is set
	if expired && e.opts.OnExpire != nil {
		e.opts.OnExpire(l)
	}
	// return the result
	return expired
}

// Remaining returns how long the link has left before it expires.
func (e *clockExpirer) Remaining(l Link) time.Duration {
	// guard against a nil receiver
	if e == nil {
		return 0
	}
	// links without an expiry never expire
	if l.ExpiresAt.IsZero() {
		return MaxTTL
	}
	// compute the remaining time
	d := l.ExpiresAt.Add(e.opts.GracePeriod).Sub(e.now())
	// never return a negative duration
	if d < 0 {
		return 0
	}
	return d
}
