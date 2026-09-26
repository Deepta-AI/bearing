// Package db holds the goose migrations; this test checks their shape.
package db

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

var name = regexp.MustCompile(`^(\d{5})_[a-z0-9_]+\.sql$`)

func TestMigrationFiles(t *testing.T) {
	files, err := filepath.Glob("migrations/*.sql")
	if err != nil {
		t.Fatal(err)
	}
	if len(files) == 0 {
		t.Fatal("no migrations found")
	}
	sort.Strings(files)
	for i, f := range files {
		base := filepath.Base(f)
		m := name.FindStringSubmatch(base)
		if m == nil {
			t.Errorf("%s: name is not NNNNN_snake_case.sql", base)
			continue
		}
		if want := fmt.Sprintf("%05d", i+1); m[1] != want {
			t.Errorf("%s: number %s, want %s (sequence has a gap or a duplicate)", base, m[1], want)
		}
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		s := string(b)
		for _, marker := range []string{"-- +goose Up", "-- +goose Down"} {
			if !strings.Contains(s, marker) {
				t.Errorf("%s: missing %q", base, marker)
			}
		}
	}
	t.Logf("checked %d migration files", len(files))
}
