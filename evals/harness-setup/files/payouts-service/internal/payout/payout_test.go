package payout

import "testing"

func TestFee(t *testing.T) {
	tests := []struct {
		amount  int64
		want    int64
		wantErr bool
	}{
		{9999, 0, true},
		{10000, 500, false},
		{1000000, 5000, false},
	}
	for _, tt := range tests {
		got, err := Fee(tt.amount)
		if (err != nil) != tt.wantErr || got != tt.want {
			t.Fatalf("Fee(%d) = %d, %v; want %d, err %v", tt.amount, got, err, tt.want, tt.wantErr)
		}
	}
}
