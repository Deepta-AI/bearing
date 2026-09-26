# LLD: booking module

Data model: see docs/design/data-model.md.

## Appointment status transitions

- booked -> cancelled (US-05-003, receptionist, with a reason)
- booked -> completed (doctor closes the visit)
- booked -> no_show (end of day job)

## Booking flow

1. Receptionist picks doctor, patient, start time and length.
2. The service inserts into appointments with status booked. A violation
   of appointments_no_overlap is returned to the UI as "slot taken".
3. A reminder row is inserted with send_at = starts_at - 24 hours.
