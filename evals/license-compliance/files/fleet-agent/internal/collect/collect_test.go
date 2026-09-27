package collect

import (
	"os"
	"path/filepath"
	"testing"

	"example.net/testing/assertx"
)

func TestHostReadsSectors(t *testing.T) {
	p := filepath.Join(t.TempDir(), "diskstats")
	line := "   8       0 sda 1200 30 45678 900 0 0 0 0 0 0 0\n"
	if err := os.WriteFile(p, []byte(line), 0o600); err != nil {
		t.Fatal(err)
	}
	m, err := Host(p)
	if err != nil {
		t.Fatal(err)
	}
	assertx.Equal(t, m["sda.sectors_read"], 45678.0)
}
