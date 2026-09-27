package reports

import (
	"net/http"
	"os"
	"strings"
)

// applyFilters narrows rows by the ?q= query when saved filters are enabled.
func applyFilters(req *http.Request, r Report) Report {
	if os.Getenv("FLAG_SAVED_FILTERS") != "true" {
		return r
	}
	q := strings.ToLower(req.URL.Query().Get("q"))
	if q == "" {
		return r
	}
	var rows [][]string
	for _, row := range r.Rows {
		for _, cell := range row {
			if strings.Contains(strings.ToLower(cell), q) {
				rows = append(rows, row)
				break
			}
		}
	}
	r.Rows = rows
	return r
}
