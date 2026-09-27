package httpapi

import (
	"encoding/csv"
	"net/http"
	"testing"
)

func TestExportInvoices(t *testing.T) {
	ts, _ := newTestServer(t)
	tests := []struct {
		name   string
		query  string
		status int
		want   [][]string
	}{
		{
			name:   "open invoices",
			query:  "?status=open",
			status: http.StatusOK,
			want: [][]string{
				{"number", "amount", "status", "due_on"},
				{"A-001", "1250", "open", "2026-09-30"},
			},
		},
		{
			name:   "limit one, newest first",
			query:  "?limit=1",
			status: http.StatusOK,
			want: [][]string{
				{"number", "amount", "status", "due_on"},
				{"A-003", "100", "draft", "2026-09-30"},
			},
		},
		{name: "unknown status", query: "?status=late", status: http.StatusBadRequest},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			res := do(t, ts, "GET", "/invoices/export"+tc.query, "key-a", "")
			if res.StatusCode != tc.status {
				t.Fatalf("status = %d, want %d", res.StatusCode, tc.status)
			}
			if tc.want == nil {
				return
			}
			got, err := csv.NewReader(res.Body).ReadAll()
			if err != nil {
				t.Fatal(err)
			}
			if len(got) != len(tc.want) {
				t.Fatalf("rows = %v, want %v", got, tc.want)
			}
			for i := range got {
				for j := range got[i] {
					if got[i][j] != tc.want[i][j] {
						t.Fatalf("row %d = %v, want %v", i, got[i], tc.want[i])
					}
				}
			}
		})
	}
}
