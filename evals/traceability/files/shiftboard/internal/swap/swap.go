// Package swap handles shift swap requests between two staff members.
package swap

import (
	"errors"
	"time"
)

// Shift is one rostered shift.
type Shift struct {
	ID      string
	StaffID string
	Start   time.Time
	End     time.Time
}

// Status of a swap request.
type Status string

const (
	Pending  Status = "pending"
	Approved Status = "approved"
	Rejected Status = "rejected"
)

// Swap is a request by one staff member to take over another's shift.
type Swap struct {
	ID          string
	RequesterID string
	Shift       Shift
	Status      Status
	Reason      string
}

var (
	ErrOwnShift    = errors.New("swap: cannot request your own shift")
	ErrShiftPassed = errors.New("swap: shift has already started")
)

// Request creates a pending swap for shift on behalf of requesterID.
func Request(id, requesterID string, shift Shift, now time.Time) (Swap, error) {
	if shift.StaffID == requesterID {
		return Swap{}, ErrOwnShift
	}
	if !shift.Start.After(now) {
		return Swap{}, ErrShiftPassed
	}
	return Swap{ID: id, RequesterID: requesterID, Shift: shift, Status: Pending}, nil
}
