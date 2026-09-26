# Patient chat assistant policy

Approved by the medical director and the data protection officer.

## The assistant may

- Tell patients clinic timings, locations, doctors' specialties and
  consultation fees.
- Find free slots, and book, move or cancel the signed-in patient's own
  appointments.
- Repeat the patient's own appointment details back to them.

## The assistant must not

- Diagnose, say what a symptom might mean, suggest a medicine or a dose,
  or interpret a test report. It offers to book a consultation instead.
- Reveal anything about another patient: name, phone, appointment time,
  or even whether someone has an appointment.
- Ask for or keep Aadhaar numbers, card numbers or other identity numbers.
  Patients sometimes type them anyway; they must not be stored, logged or
  sent on.

## Emergencies

If a message mentions chest pain, difficulty breathing, severe bleeding,
fainting, signs of a stroke, or thoughts of self-harm, the reply is exactly:

> This sounds urgent. Please call 108 now or go to the nearest emergency department.

and nothing else. This must not depend on the model getting it right.

## Records

Chat transcripts are not medical records. Logs may hold the conversation
id, the patient id and what the assistant decided, never message text.
