package invoice

import (
	"context"
	"errors"
	"testing"
	"time"
)

type memRepo struct{ invs map[int64]Invoice }

func (m *memRepo) ListForAccount(_ context.Context, accountID int64, status Status) ([]Invoice, error) {
	var out []Invoice
	for _, inv := range m.invs {
		if inv.AccountID == accountID && (status == "" || inv.Status == status) {
			out = append(out, inv)
		}
	}
	return out, nil
}

func (m *memRepo) GetForAccount(_ context.Context, accountID, id int64) (Invoice, error) {
	inv, ok := m.invs[id]
	if !ok || inv.AccountID != accountID {
		return Invoice{}, ErrNotFound
	}
	return inv, nil
}

func (m *memRepo) Get(_ context.Context, id int64) (Invoice, error) {
	inv, ok := m.invs[id]
	if !ok {
		return Invoice{}, ErrNotFound
	}
	return inv, nil
}

func (m *memRepo) Export(ctx context.Context, accountID int64, status Status, _ string, _ int) ([]Invoice, error) {
	return m.ListForAccount(ctx, accountID, status)
}

func (m *memRepo) SetStatus(_ context.Context, accountID, id int64, status Status, paidAt *time.Time) error {
	inv, ok := m.invs[id]
	if !ok || inv.AccountID != accountID {
		return ErrNotFound
	}
	inv.Status, inv.PaidAt = status, paidAt
	m.invs[id] = inv
	return nil
}

func TestMarkPaid(t *testing.T) {
	now := time.Date(2026, 9, 20, 10, 0, 0, 0, time.UTC)
	tests := []struct {
		name    string
		account int64
		id      int64
		wantErr error
	}{
		{name: "open invoice", account: 1, id: 10},
		{name: "already paid", account: 1, id: 11, wantErr: ErrInvalidState},
		{name: "draft", account: 1, id: 12, wantErr: ErrInvalidState},
		{name: "other account", account: 2, id: 10, wantErr: ErrNotFound},
		{name: "missing", account: 1, id: 99, wantErr: ErrNotFound},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			repo := &memRepo{invs: map[int64]Invoice{
				10: {ID: 10, AccountID: 1, Status: StatusOpen},
				11: {ID: 11, AccountID: 1, Status: StatusPaid},
				12: {ID: 12, AccountID: 1, Status: StatusDraft},
			}}
			svc := &Service{Repo: repo, Now: func() time.Time { return now }}
			inv, err := svc.MarkPaid(context.Background(), tc.account, tc.id)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("err = %v, want %v", err, tc.wantErr)
			}
			if tc.wantErr == nil && (inv.Status != StatusPaid || !inv.PaidAt.Equal(now)) {
				t.Fatalf("invoice = %+v, want paid at %v", inv, now)
			}
		})
	}
}
