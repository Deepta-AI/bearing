# Signup: flows

## Create account (`signup`)

Job: get a studio owner from the landing page to an account in under a minute.
Primary action: Create account.

Fields: Work email, Password (at least 12 characters), Studio name. Each has a visible label.

States:

- default: the form.
- email-taken: under the email field, "An account with this email already exists." with a "Sign in instead" link.

## Verify email (`verify`)

Job: confirm the email with the 6 digit code we sent.
Primary action: Verify.

States:

- default: six digit code field, "Resend code" link.
- wrong-code: "That code doesn't match. Check the latest email or resend the code."
