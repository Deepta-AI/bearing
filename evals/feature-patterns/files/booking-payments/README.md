# clinic-bookings

Appointment bookings for our partner clinics, with the patient Android
app in clients/android. Clinics already pay us a monthly SaaS fee through
Razorpay subscriptions; the webhook for that lives in internal/payments.

Next: patients pay for a booking in the app (docs/product/backlog.md,
US-09-001 to US-09-003).

    go run ./cmd/api
