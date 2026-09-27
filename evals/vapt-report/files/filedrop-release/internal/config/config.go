// Package config reads the service settings from the environment.
package config

import "os"

// Config is the service configuration.
type Config struct {
	Addr          string
	SessionSecret []byte
	AVScanURL     string
	AVScanKey     string
}

// Load reads the configuration from the environment.
func Load() Config {
	secret := os.Getenv("SESSION_SECRET")
	if secret == "" {
		// Local development convenience so `make run` works without a .env.
		secret = "filedrop-dev-secret"
	}
	return Config{
		Addr:          getenv("ADDR", ":8080"),
		SessionSecret: []byte(secret),
		AVScanURL:     getenv("AVSCAN_URL", "http://localhost:9400/scan"),
		AVScanKey:     os.Getenv("AVSCAN_API_KEY"),
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
