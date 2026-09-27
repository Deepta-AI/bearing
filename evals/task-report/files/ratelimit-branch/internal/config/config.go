// Package config reads the service settings from the environment.
package config

import (
	"os"
	"strconv"
)

// Config holds the service settings.
type Config struct {
	Addr             string
	RateLimitEnabled bool
}

// Load reads the settings from the environment, falling back to defaults.
func Load() Config {
	return Config{
		Addr:             env("ADDR", ":8080"),
		RateLimitEnabled: envBool("RATE_LIMIT_ENABLED", false),
	}
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return def
}

func envBool(key string, def bool) bool {
	v, ok := os.LookupEnv(key)
	if !ok {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return def
	}
	return b
}
