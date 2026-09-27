package reports

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/reportsvc/internal/flags"
)

func sample() *Store {
	return NewStore(
		Report{ID: "r1", AccountID: "a1", Title: "Signups", Columns: []string{"day", "count"}, Rows: [][]string{{"mon", "4"}, {"tue", "7"}}},
		Report{ID: "r2", AccountID: "a1", Title: "Churn", Columns: []string{"month", "rate"}, Rows: [][]string{{"aug", "2.1"}}},
	)
}

func serve(h *Handler, path string) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	h.Routes(mux)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestGetReport(t *testing.T) {
	rec := serve(&Handler{Store: sample(), Flags: flags.With()}, "/reports/r1")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Signups") {
		t.Fatalf("got %d %q", rec.Code, rec.Body.String())
	}
}

func TestUnknownReport(t *testing.T) {
	rec := serve(&Handler{Store: sample(), Flags: flags.With()}, "/reports/nope")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("got %d", rec.Code)
	}
}

func TestGetReportLinksToCSV(t *testing.T) {
	rec := serve(&Handler{Store: sample(), Flags: flags.With()}, "/reports/r1")
	if !strings.Contains(rec.Body.String(), `"csv":"/reports/r1/export.csv"`) {
		t.Fatalf("no csv link in %q", rec.Body.String())
	}
}

func TestExportCSV(t *testing.T) {
	rec := serve(&Handler{Store: sample(), Flags: flags.With()}, "/reports/r1/export.csv")
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d", rec.Code)
	}
	if got, want := rec.Body.String(), "day,count\nmon,4\ntue,7\n"; got != want {
		t.Fatalf("csv %q, want %q", got, want)
	}
}

func TestAuditOnlyWhenFlagOn(t *testing.T) {
	var seen []string
	h := &Handler{Store: sample(), Flags: flags.With(), Audit: func(id string) { seen = append(seen, id) }}
	serve(h, "/reports/r1")
	if len(seen) != 0 {
		t.Fatalf("audited with flag off: %v", seen)
	}
	h.Flags = flags.With(flags.AuditLogV2)
	serve(h, "/reports/r1")
	if len(seen) != 1 {
		t.Fatalf("not audited with flag on: %v", seen)
	}
}

type fakeSender struct{ sent []Email }

func (f *fakeSender) Send(e Email) error { f.sent = append(f.sent, e); return nil }

func TestWeeklyDigest(t *testing.T) {
	fs := &fakeSender{}
	d := &Digest{Store: sample(), Sender: fs, BaseURL: "https://reports.example.com"}
	if err := d.SendWeekly("a1", "owner@example.com"); err != nil {
		t.Fatal(err)
	}
	if len(fs.sent) != 1 {
		t.Fatalf("sent %d", len(fs.sent))
	}
	e := fs.sent[0]
	if !strings.Contains(e.Body, "Signups") || !strings.Contains(e.Body, "Churn") {
		t.Fatalf("body %q", e.Body)
	}
	if !strings.Contains(e.Body, "https://reports.example.com/reports/r1/export.csv") {
		t.Fatalf("no download link in %q", e.Body)
	}
	if len(e.Attachments) != 2 {
		t.Fatalf("attachments %d", len(e.Attachments))
	}
}

type memSink map[string][]byte

func (m memSink) Put(key string, body []byte) error { m[key] = body; return nil }

func TestArchiveWritesEveryReportAsCSV(t *testing.T) {
	sink := memSink{}
	n, err := Archive(sample(), sink)
	if err != nil || n != 2 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	if got, want := string(sink["archive/a1/r1.csv"]), "day,count\nmon,4\ntue,7\n"; got != want {
		t.Fatalf("csv %q, want %q", got, want)
	}
}
