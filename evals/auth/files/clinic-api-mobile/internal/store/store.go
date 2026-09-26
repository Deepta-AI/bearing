package store

import (
	"errors"
	"sync"
	"time"
)

var ErrNotFound = errors.New("not found")

type User struct {
	ID       string
	ClinicID string
	Role     string
	Email    string
	password string
	// Deactivated staff cannot sign in (US-01-006).
	Deactivated bool
}

type Patient struct {
	ID       string `json:"id"`
	ClinicID string `json:"clinic_id"`
	Name     string `json:"name"`
	Phone    string `json:"phone"`
}

type Appointment struct {
	ID        string    `json:"id"`
	ClinicID  string    `json:"clinic_id"`
	PatientID string    `json:"patient_id"`
	DoctorID  string    `json:"doctor_id"`
	At        time.Time `json:"at"`
	Cancelled bool      `json:"cancelled"`
	Notes     string    `json:"-"`
}

type Store struct {
	mu           sync.Mutex
	users        []User
	patients     map[string]Patient
	appointments map[string]*Appointment
}

func (s *Store) CheckPassword(email, password string) (User, bool) {
	for _, u := range s.users {
		if u.Email == email && u.password == password && !u.Deactivated {
			return u, true
		}
	}
	return User{}, false
}

// AppointmentByID loads an appointment of the given clinic by its id.
func (s *Store) AppointmentByID(clinicID, id string) (Appointment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ok := s.appointments[id]
	if !ok || a.ClinicID != clinicID {
		return Appointment{}, ErrNotFound
	}
	return *a, nil
}

// CancelAppointment marks an appointment of the given clinic cancelled.
func (s *Store) CancelAppointment(clinicID, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ok := s.appointments[id]
	if !ok || a.ClinicID != clinicID {
		return ErrNotFound
	}
	a.Cancelled = true
	return nil
}

// PatientByID loads a patient of the given clinic by its id.
func (s *Store) PatientByID(clinicID, id string) (Patient, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.patients[id]
	if !ok || p.ClinicID != clinicID {
		return Patient{}, ErrNotFound
	}
	return p, nil
}

// AppointmentsForClinic lists a clinic's appointments.
func (s *Store) AppointmentsForClinic(clinicID string) []Appointment {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Appointment
	for _, a := range s.appointments {
		if a.ClinicID == clinicID {
			out = append(out, *a)
		}
	}
	return out
}

// Deactivate marks a staff member of the given clinic as deactivated.
func (s *Store) Deactivate(clinicID, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.users {
		if s.users[i].ID == userID && s.users[i].ClinicID == clinicID {
			s.users[i].Deactivated = true
			return nil
		}
	}
	return ErrNotFound
}
