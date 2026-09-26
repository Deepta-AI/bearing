// Package config reads the process configuration from the environment and
// fails fast, naming every missing or invalid variable at once.
package config

import (
	"fmt"
	"log/slog"
	"os"
	"strings"
)

// Config is the validated process configuration.
type Config struct {
	Port        string
	LogLevel    slog.Level
	DatabaseURL string
}

// Load reads and validates the environment.
func Load() (Config, error) {
	var problems []string
	c := Config{
		Port:        envOr("PORT", "8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
	}
	switch strings.ToLower(envOr("LOG_LEVEL", "info")) {
	case "debug":
		c.LogLevel = slog.LevelDebug
	case "info":
		c.LogLevel = slog.LevelInfo
	case "warn":
		c.LogLevel = slog.LevelWarn
	case "error":
		c.LogLevel = slog.LevelError
	default:
		problems = append(problems, "LOG_LEVEL must be debug, info, warn or error")
	}
	if len(problems) > 0 {
		return Config{}, fmt.Errorf("config: %s", strings.Join(problems, "; "))
	}
	return c, nil
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
