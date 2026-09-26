// Package patients stores patient records for a tenant.
package patients

import (
	"context"
	"database/sql"
	"time"
)

// Patient is one row of the patients table.
type Patient struct {
	ID          int64
	TenantID    int64
	FullName    string
	Phone       string
	DateOfBirth *time.Time
}

// Store reads and writes patients.
type Store struct{ DB *sql.DB }

// ByID returns one patient of the tenant.
func (s *Store) ByID(ctx context.Context, tenantID, id int64) (Patient, error) {
	var p Patient
	err := s.DB.QueryRowContext(ctx,
		`SELECT id, tenant_id, full_name, phone, date_of_birth
		   FROM patients WHERE tenant_id = $1 AND id = $2`,
		tenantID, id).Scan(&p.ID, &p.TenantID, &p.FullName, &p.Phone, &p.DateOfBirth)
	return p, err
}
