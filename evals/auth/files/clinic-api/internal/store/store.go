package store

import (
	"errors"
	"sort"
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
		if u.Email == email && u.password == password {
			return u, true
		}
	}
	return User{}, false
}

// AppointmentByID loads an appointment by its id.
func (s *Store) AppointmentByID(id string) (Appointment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ok := s.appointments[id]
	if !ok {
		return Appointment{}, ErrNotFound
	}
	return *a, nil
}

// CancelAppointment marks an appointment cancelled.
func (s *Store) CancelAppointment(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ok := s.appointments[id]
	if !ok {
		return ErrNotFound
	}
	a.Cancelled = true
	return nil
}

// PatientByID loads a patient by its id.
func (s *Store) PatientByID(id string) (Patient, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.patients[id]
	if !ok {
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

// AppointmentsForPatient lists a patient's appointments, oldest first.
func (s *Store) AppointmentsForPatient(patientID string) []Appointment {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Appointment
	for _, a := range s.appointments {
		if a.PatientID == patientID {
			out = append(out, *a)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].At.Before(out[j].At) })
	return out
}
