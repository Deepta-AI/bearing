# PRD: Appointments and reminders

## Problem

Receptionists book appointments in a paper diary and phone patients the
day before. Double bookings happen weekly and no-shows run at about 18%.

## Scope (phase 1)

- Book, reschedule and cancel appointments for a patient with a doctor.
- A doctor's day view for the front desk.
- SMS reminder the day before each appointment.
- Consultation fee captured at booking.

## Out of scope (phase 2)

- Waitlist for fully booked days.
- Telehealth video rooms.
- Online booking by patients themselves.

## Volumes

- About 400 clinics at launch in India, the UAE and Singapore, 3 to 12
  doctors each. Each clinic works in its own local time.
- About 2.4 million appointments a year across all tenants, growing with
  new clinics. Every appointment gets one reminder.
- The day view is opened constantly during clinic hours: expect around 50
  reads a second at peak.

## Compliance

Appointment records are clinical records and must be kept for 7 years
after the appointment date. Nothing else in this feature has a retention
rule agreed yet.

A patient may ask their clinic to delete their personal data. The clinic
must act on the request within 30 days, except for records a law requires
it to keep.
