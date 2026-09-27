// Package flags is the only place that reads feature flag values.
// See docs/adr/0002-feature-flags.md.
package flags

import (
	"os"
	"strings"
)

// Flag is a feature flag name.
type Flag string

const (
	AuditLogV2   Flag = "audit_log_v2"
	SavedFilters Flag = "saved_filters"
)

// All lists every flag, for Load.
var All = []Flag{AuditLogV2, SavedFilters}

// Set holds flag values, read once at startup.
type Set struct {
	on map[Flag]bool
}

// envName returns the environment variable for f, for example FLAG_AUDIT_LOG_V2.
func envName(f Flag) string {
	return "FLAG_" + strings.ToUpper(string(f))
}

// Load reads every flag from getenv. A flag with no value is off.
func Load(getenv func(string) string) *Set {
	s := &Set{on: map[Flag]bool{}}
	for _, f := range All {
		s.on[f] = getenv(envName(f)) != ""
	}
	return s
}

// FromEnv loads the flags from the process environment.
func FromEnv() *Set { return Load(os.Getenv) }

// With returns a Set with exactly the given flags on, for tests.
func With(on ...Flag) *Set {
	s := &Set{on: map[Flag]bool{}}
	for _, f := range on {
		s.on[f] = true
	}
	return s
}

// Enabled reports whether f is on.
func (s *Set) Enabled(f Flag) bool {
	if s == nil {
		return false
	}
	return s.on[f]
}
