package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"example.com/billing-api/internal/auth"
	"example.com/billing-api/internal/invoice"
)

// fakeRepo is an in-memory invoice.Repo and auth.KeyLookup.
type fakeRepo struct {
	mu   sync.Mutex
	keys map[string]int64
	invs map[int64]invoice.Invoice
}

func (f *fakeRepo) AccountForKey(_ context.Context, key string) (int64, error) {
	id, ok := f.keys[key]
	if !ok {
		return 0, auth.ErrUnknownKey
	}
	return id, nil
}

func (f *fakeRepo) ListForAccount(_ context.Context, accountID int64, status invoice.Status) ([]invoice.Invoice, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []invoice.Invoice
	for _, inv := range f.invs {
		if inv.AccountID == accountID && (status == "" || inv.Status == status) {
			out = append(out, inv)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (f *fakeRepo) GetForAccount(_ context.Context, accountID, id int64) (invoice.Invoice, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	inv, ok := f.invs[id]
	if !ok || inv.AccountID != accountID {
		return invoice.Invoice{}, invoice.ErrNotFound
	}
	return inv, nil
}

func (f *fakeRepo) Get(_ context.Context, id int64) (invoice.Invoice, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	inv, ok := f.invs[id]
	if !ok {
		return invoice.Invoice{}, invoice.ErrNotFound
	}
	return inv, nil
}

func (f *fakeRepo) SetStatus(_ context.Context, accountID, id int64, status invoice.Status, paidAt *time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	inv, ok := f.invs[id]
	if !ok || inv.AccountID != accountID {
		return invoice.ErrNotFound
	}
	inv.Status, inv.PaidAt = status, paidAt
	f.invs[id] = inv
	return nil
}

var testNow = time.Date(2026, 9, 20, 10, 0, 0, 0, time.UTC)

// newTestServer serves two accounts: key-a owns invoices 1 to 3, key-b owns 4.
func newTestServer(t *testing.T) (*httptest.Server, *fakeRepo) {
	t.Helper()
	day := func(d int) time.Time { return time.Date(2026, 9, d, 9, 0, 0, 0, time.UTC) }
	repo := &fakeRepo{
		keys: map[string]int64{"key-a": 1, "key-b": 2},
		invs: map[int64]invoice.Invoice{
			1: {ID: 1, AccountID: 1, Number: "A-001", AmountPaise: 125000, Status: invoice.StatusOpen, DueOn: day(30), CreatedAt: day(1)},
			2: {ID: 2, AccountID: 1, Number: "A-002", AmountPaise: 49900, Status: invoice.StatusPaid, DueOn: day(30), CreatedAt: day(2)},
			3: {ID: 3, AccountID: 1, Number: "A-003", AmountPaise: 10000, Status: invoice.StatusDraft, DueOn: day(30), CreatedAt: day(3)},
			4: {ID: 4, AccountID: 2, Number: "B-001", AmountPaise: 777700, Status: invoice.StatusOpen, DueOn: day(30), CreatedAt: day(4)},
		},
	}
	srv := &Server{
		Invoices: &invoice.Service{Repo: repo, Now: func() time.Time { return testNow }},
		Keys:     repo,
		Log:      slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	ts := httptest.NewServer(srv.Handler())
	t.Cleanup(ts.Close)
	return ts, repo
}

func do(t *testing.T, ts *httptest.Server, method, path, key, body string) *http.Response {
	t.Helper()
	var rd io.Reader
	if body != "" {
		rd = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, ts.URL+path, rd)
	if err != nil {
		t.Fatal(err)
	}
	if key != "" {
		req.Header.Set("X-API-Key", key)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { res.Body.Close() })
	return res
}
