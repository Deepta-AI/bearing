package jobs

import (
	"context"
	"testing"
	"time"
)

type fakeDB struct {
	query string
	args  []any
}

func (f *fakeDB) Exec(_ context.Context, q string, args ...any) (int64, error) {
	f.query, f.args = q, args
	return 3, nil
}

func TestPurgePingsDeletesBeforeCutoff(t *testing.T) {
	now := time.Date(2026, 9, 1, 1, 15, 0, 0, time.UTC)
	db := &fakeDB{}
	n, err := PurgePings(context.Background(), db, now)
	if err != nil || n != 3 {
		t.Fatalf("PurgePings = %d, %v", n, err)
	}
	if got := db.args[0].(time.Time); !got.Equal(PingCutoff(now)) {
		t.Fatalf("cutoff = %v, want %v", got, PingCutoff(now))
	}
}
