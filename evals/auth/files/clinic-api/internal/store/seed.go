package store

import "time"

// Seeded returns a store with two clinics, three staff at Anand Clinic,
// one admin at Bharat Clinic, and one appointment per clinic.
func Seeded() *Store {
	at := time.Date(2026, 10, 5, 10, 30, 0, 0, time.UTC)
	return &Store{
		users: []User{
			{ID: "u-1", ClinicID: "c-anand", Role: "admin", Email: "admin@anand.test", password: "pw"},
			{ID: "u-2", ClinicID: "c-anand", Role: "doctor", Email: "doctor@anand.test", password: "pw"},
			{ID: "u-3", ClinicID: "c-anand", Role: "receptionist", Email: "desk@anand.test", password: "pw"},
			{ID: "u-9", ClinicID: "c-bharat", Role: "admin", Email: "admin@bharat.test", password: "pw"},
		},
		patients: map[string]Patient{
			"p-1": {ID: "p-1", ClinicID: "c-anand", Name: "Meera Iyer", Phone: "+91 98450 00001"},
			"p-7": {ID: "p-7", ClinicID: "c-bharat", Name: "Kiran Rao", Phone: "+91 98450 00007"},
		},
		appointments: map[string]*Appointment{
			"a-1": {ID: "a-1", ClinicID: "c-anand", PatientID: "p-1", DoctorID: "u-2", At: at, Notes: "Follow-up for hypertension."},
			"a-7": {ID: "a-7", ClinicID: "c-bharat", PatientID: "p-7", DoctorID: "u-8", At: at, Notes: "Post-operative review."},
		},
	}
}
