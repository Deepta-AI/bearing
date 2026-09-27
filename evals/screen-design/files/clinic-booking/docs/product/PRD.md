# PRD: Book a visit

Version 1.0, 1 Sep 2026.

## Requirements

- REQ-101: A patient picks a clinic, a day and a free 30 minute slot.
- REQ-102: The patient gives name and mobile number; the number is
  verified by OTP before the booking is made.
- REQ-103: A confirmation screen shows clinic, date, time and the
  consultation fee, which is paid at the clinic.
- REQ-104: After booking, the patient sees the booking and can find it
  again under My bookings.
- REQ-105: Cancellation follows the clinic cancellation policy (legal owns
  the wording).

## Out of scope for v1

- Online payment of any kind. The fee is paid at the clinic (ADR-0003).
- Rescheduling. A patient cancels and books again.
- Doctor choice; the clinic assigns the doctor.
