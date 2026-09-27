# Kiosk check-in: flows

The kiosk screen faces the waiting room. Anything on it can be read by
the people queuing behind the patient.

## Screens

| Id | Screen | Template |
| --- | --- | --- |
| K-01 | Enter booking code | templates/start.html |
| K-02 | Checked in | templates/confirmed.html |
| K-03 | No match | templates/notfound.html |

## Copy

- K-01 title: "Check in for your appointment"
- K-01 hint: "Your booking code is in the SMS we sent you. It has six
  letters and numbers."
- K-01 second field: "Last two digits of your birth year"
- K-01 action: "Check me in"
- K-02 title: "You're checked in, <display name>"
- K-02 body: "Please wait in <waiting area>. We will call your token
  number." Token number shown large, for example "B-14".
- K-03 title: "We couldn't find that booking"
- K-03 body: "Check the code in your SMS and try again, or ask at the
  front desk." Action: "Try again"

## Privacy

The display name is the first name and the initial of the last name
(internal/kiosk/display.go). Never show the full name, the phone number,
the birth year, the doctor's specialty or the reason for the visit on
any kiosk screen.

## Timing

After 30 seconds without a touch, K-02 and K-03 return to K-01.
