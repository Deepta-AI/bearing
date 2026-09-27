package ledger

import "testing"

func TestApply(t *testing.T) {
	tests := []struct {
		name    string
		ps      []Posting
		wantErr bool
		wantA   int64
	}{
		{"balanced transfer", []Posting{{"a", -500}, {"b", 500}}, false, -500},
		{"unbalanced", []Posting{{"a", -500}, {"b", 400}}, true, 0},
		{"single posting", []Posting{{"a", 0}}, true, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b := New()
			err := b.Apply(tt.ps...)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Apply() error = %v, wantErr %v", err, tt.wantErr)
			}
			if got := b.Balance("a"); got != tt.wantA {
				t.Fatalf("Balance(a) = %d, want %d", got, tt.wantA)
			}
		})
	}
}
