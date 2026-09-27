package swap

import "testing"

// TC-0003: a manager approves or rejects a pending swap; a rejection needs a reason.
func TestManagerDecision(t *testing.T) {
	s := Swap{ID: "sw-3", Status: Pending}
	a, err := Approve(s)
	if err != nil || a.Status != Approved {
		t.Fatalf("approve: %v %s", err, a.Status)
	}
	if _, err := Reject(s, ""); err == nil {
		t.Fatal("reject without reason accepted")
	}
	r, err := Reject(s, "understaffed")
	if err != nil || r.Status != Rejected {
		t.Fatalf("reject: %v %s", err, r.Status)
	}
	if _, err := Approve(r); err != ErrNotPending {
		t.Fatalf("approve after reject: %v", err)
	}
}
