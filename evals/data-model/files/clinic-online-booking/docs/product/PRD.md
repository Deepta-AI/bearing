# PRD: Appointments and reminders

## Problem

Receptionists book appointments in a paper diary and phone patients the
day before. Double bookings happen weekly and no-shows run at about 18%.

## Scope (phase 1)

- Book, reschedule and cancel appointments for a patient with a doctor.
- A doctor's day view for the front desk.
- SMS reminder the day before each appointment.
- Consultation fee captured at booking.

## Phase 1b (next sprint)

- Online booking by patients themselves (US-05-009, US-05-010).

## Out of scope (phase 2)

- Waitlist for fully booked days.
- Telehealth video rooms.

## Volumes

- About 400 clinics at launch, 3 to 12 doctors each.
- About 2.4 million appointments a year across all tenants, growing with
  new clinics. Every appointment gets one reminder.
- The day view is opened constantly during clinic hours: expect around 50
  reads a second at peak.

## Compliance

Appointment records are clinical records and must be kept for 7 years
after the appointment date. Nothing else in this feature has a retention
rule agreed yet.
