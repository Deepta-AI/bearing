package config

import (
	"log/slog"
	"testing"
)

func TestLoad(t *testing.T) {
	cases := []struct {
		name    string
		level   string
		want    slog.Level
		wantErr bool
	}{
		{name: "default level is info", level: "", want: slog.LevelInfo},
		{name: "debug parses", level: "debug", want: slog.LevelDebug},
		{name: "unknown level is an error", level: "loud", wantErr: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("LOG_LEVEL", tc.level)

			got, err := Load()

			if tc.wantErr {
				if err == nil {
					t.Fatal("expected an error")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got.LogLevel != tc.want {
				t.Fatalf("level: got %v want %v", got.LogLevel, tc.want)
			}
		})
	}
}
