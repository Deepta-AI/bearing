package appointments

import (
	"context"
	"database/sql"
	"time"
)

type Appointment struct {
	ID        int64
	ClinicID  int64
	PatientID int64
	StartsAt  time.Time
	Reason    string // free text typed by the front desk, often clinical
	Status    string // booked | cancelled | completed
}

type Store struct{ DB *sql.DB }

// Create inserts the appointment inside one transaction so that later
// side effects can be added to the same unit of work.
func (s *Store) Create(ctx context.Context, a *Appointment) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	err = tx.QueryRowContext(ctx,
		`INSERT INTO appointments (clinic_id, patient_id, starts_at, reason, status)
		 VALUES ($1, $2, $3, $4, 'booked') RETURNING id`,
		a.ClinicID, a.PatientID, a.StartsAt, a.Reason).Scan(&a.ID)
	if err != nil {
		return err
	}
	return tx.Commit()
}

// Reschedule moves an appointment to a new start time.
func (s *Store) Reschedule(ctx context.Context, id int64, startsAt time.Time) error {
	_, err := s.DB.ExecContext(ctx,
		`UPDATE appointments SET starts_at = $2 WHERE id = $1 AND status = 'booked'`, id, startsAt)
	return err
}

// Cancel marks an appointment cancelled.
func (s *Store) Cancel(ctx context.Context, id int64) error {
	_, err := s.DB.ExecContext(ctx,
		`UPDATE appointments SET status = 'cancelled' WHERE id = $1`, id)
	return err
}
