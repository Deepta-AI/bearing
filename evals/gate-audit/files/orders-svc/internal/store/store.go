// Package store holds the SQL the service runs.
package store

import (
	"embed"
	"sort"
	"strings"
)

//go:embed queries/*.sql
var files embed.FS

// Query returns the SQL for a named query, for example "get_order".
func Query(name string) (string, bool) {
	b, err := files.ReadFile("queries/" + name + ".sql")
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(b)), true
}

// Names lists the embedded queries.
func Names() []string {
	entries, _ := files.ReadDir("queries")
	var out []string
	for _, e := range entries {
		out = append(out, strings.TrimSuffix(e.Name(), ".sql"))
	}
	sort.Strings(out)
	return out
}
