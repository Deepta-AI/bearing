package version

import (
	"os"
	"strings"
	"testing"
)

func TestVersionMatchesFile(t *testing.T) {
	b, err := os.ReadFile("../../VERSION")
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(b)); got != Version {
		t.Fatalf("VERSION file says %q, version.Version is %q", got, Version)
	}
}
