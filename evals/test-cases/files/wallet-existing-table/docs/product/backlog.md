# Backlog

### US-01-001 Sign in with a one-time password
REQ-001

- AC-US-01-001-1: Given a registered phone number, when the user requests
  a code, then a 6 digit code is sent by SMS and is valid for 5 minutes.
- AC-US-01-001-2: When the user enters the correct code within 5 minutes,
  then they are signed in.
- AC-US-01-001-3: After 5 wrong codes for one phone number the number is
  locked for 30 minutes and the screen says "Too many attempts. Try again
  in 30 minutes."

### US-02-001 Move money between my wallets
REQ-004

- AC-US-02-001-1: The user can move an amount from one of their wallets to
  another of their wallets; both balances update at once.
- AC-US-02-001-2: The amount must be at least 1.00 and at most the source
  wallet's balance; otherwise the move is refused with "Enter an amount
  between 1.00 and your balance."
- AC-US-02-001-3: The transfer screen works correctly.

### US-03-001 Set a display name
REQ-007

- AC-US-03-001-1: The display name is 1 to 30 characters; letters, digits,
  spaces and hyphens only.

### US-04-001 Download a monthly statement
REQ-009

- AC-US-04-001-1: The user picks a month from the last 12 and downloads a
  PDF listing every transaction of that month in date order.
- AC-US-04-001-2: A month with no transactions gives a PDF that says "No
  transactions in <Month YYYY>."
