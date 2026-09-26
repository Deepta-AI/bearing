# Backlog: appointments (epic 05)

### US-05-001 Doctor's day view
As a receptionist I see one doctor's appointments for a chosen day, in
start time order, so I can check people in.

### US-05-002 Book an appointment
As a receptionist I book a patient with a doctor at a start time.
Appointments are 15, 30 or 45 minutes long. A doctor can never have two
appointments that overlap, even for a moment.

### US-05-003 Cancel or reschedule
As a receptionist I cancel an appointment with a reason, or move it to
another time. A cancelled slot becomes free for booking again.

### US-05-004 SMS reminder
The patient gets an SMS 24 hours before the appointment, sent to the
phone number on the patient record. A failed send is retried up to 3
times. The front desk can see whether the reminder was delivered.

### US-05-005 Patient appointment history
As a receptionist I see all of a patient's appointments, newest first.

### US-05-006 Reason for visit
At booking the receptionist types the reason for the visit (free text,
for example "follow-up, chest pain").

### US-05-007 Consultation fee
Each doctor has a default consultation fee. The fee is copied onto the
appointment at booking and can be changed for that appointment.

### US-05-009 Patient online account
A patient signs in to a clinic's booking page with their email address
and a one-time code; sign-in codes are issued and checked by the existing
auth-gateway service and are not stored by clinicdesk. The same email may
belong to accounts at different clinics, one account per clinic. A
patient can close their account; the email address is deleted 30 days
after the account is closed. The front desk can see which appointments
were booked online.

### US-05-010 Slot hold during online booking
When a patient picks a slot online, the slot is held for 10 minutes while
they confirm. No one else can book a held slot. If the patient does not
confirm within 10 minutes the hold lapses and the slot is free again.
