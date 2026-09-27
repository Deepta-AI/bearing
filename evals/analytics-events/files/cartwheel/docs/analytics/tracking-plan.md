# Tracking plan

## Identity

- Anonymous id per device until signup or login; the server calls
  `identify(user_id)` at signup and login.
- Email, phone and address never travel as event properties.

## Consent

- Web: the analytics module drops every call until the visitor accepts the
  cookie banner.
- Mobile: the consent step in onboarding; nothing is sent before it.
- Server: outcome events (signup, orders) only, no personal data.

## Rules

- One row per event in the sheet, the same name and properties on every
  platform.
- Amounts are integers in minor units (paise) with `currency`.
- Outcomes (`signed_up`, `order_placed`, `order_cancelled`) are emitted by
  the server only.
