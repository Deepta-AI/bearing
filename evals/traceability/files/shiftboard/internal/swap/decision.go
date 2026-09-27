package swap

import "errors"

var ErrNotPending = errors.New("swap: only a pending swap can be decided")

// Approve marks a pending swap approved.
func Approve(s Swap) (Swap, error) {
	if s.Status != Pending {
		return s, ErrNotPending
	}
	s.Status = Approved
	return s, nil
}

// Reject marks a pending swap rejected with the manager's reason.
func Reject(s Swap, reason string) (Swap, error) {
	if s.Status != Pending {
		return s, ErrNotPending
	}
	if reason == "" {
		return s, errors.New("swap: a rejection needs a reason")
	}
	s.Status = Rejected
	s.Reason = reason
	return s, nil
}
