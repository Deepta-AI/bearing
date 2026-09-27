package reports

import (
	"bytes"
	"encoding/csv"
)

// BuildCSV renders a report as CSV with a header row.
func BuildCSV(r Report) ([]byte, error) {
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)
	if err := w.Write(r.Columns); err != nil {
		return nil, err
	}
	if err := w.WriteAll(r.Rows); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
