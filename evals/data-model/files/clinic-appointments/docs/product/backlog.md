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
