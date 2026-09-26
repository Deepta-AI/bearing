package bookings

import "time"

type Status string

const (
	StatusPending Status = "pending"
	StatusPaid    Status = "paid"
)

type Booking struct {
	ID          string
	ClinicID    string
	PatientID   string
	At          time.Time
	PriceRupees float64
	Status      Status
}
