package payment

import "testing"

// US-02-003: captured and settled mark the payment captured; an unknown status leaves it pending.
func TestWebhookStatus(t *testing.T) {
	for in, want := range map[string]string{"captured": "captured", "settled": "captured", "refund_initiated": "pending"} {
		if got := WebhookStatus(in); got != want {
			t.Fatalf("WebhookStatus(%q) = %q, want %q", in, got, want)
		}
	}
}
