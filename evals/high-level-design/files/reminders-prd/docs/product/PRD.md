# PRD: Appointment reminders

Owner: Product (clinics). Status: approved for design, 2026-09-15.

## Problem
About 11% of booked appointments are no-shows. Clinics call patients by
hand the day before, which takes front-desk time and still misses most.

## Numbers
- 1,400 clinics on the platform, about 90,000 appointments a day.
- Most clinics open at 09:00; on weekdays about 12,000 appointments start
  at exactly 09:00.
- The second cluster is after the mid-morning break: on weekdays about
  6,000 appointments start at exactly 11:00.

## Requirements
- REQ-201: Send an SMS reminder 24 hours before each booked appointment.
- REQ-202: Send a second SMS reminder 2 hours before.
- REQ-203: Each reminder goes out within 10 minutes of its due time.
- REQ-204: A cancelled appointment gets no further reminders; a
  rescheduled one is reminded for the new time only.
- REQ-205: A patient who replies STOP gets no more reminders from any
  clinic (the sms_opt_out flag).
- REQ-206: A clinic admin can switch reminders off for their clinic.

## Message
Clinic name, date and time, and the clinic phone number. Nothing about the
reason for the visit.

## Out of scope
- WhatsApp or email reminders (a later release).
- Confirming or rescheduling by replying to the SMS.
- Reminders for walk-ins.
