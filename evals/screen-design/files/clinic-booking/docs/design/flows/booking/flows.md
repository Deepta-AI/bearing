# Flows: book a visit

## 1. Screens

| id | screen | job |
|----|--------|-----|
| S-01 | Pick a slot | Choose a free time on the chosen day |
| S-02 | Your details | Give name and mobile number, verify by OTP |
| S-03 | Confirm booking | Check the visit and the fee, then book |
| S-04 | Booked | See the booking and where to find it again |

## 2. Interaction states

### S-01 Pick a slot

| state | when |
|-------|------|
| loading | fetching slots |
| success | slots listed |
| no slots | closed day or fully booked |
| error | slots call failed |

### S-02 Your details

| state | when |
|-------|------|
| default | form |
| invalid | a field fails validation |
| verifying | OTP sent, waiting for the code |

### S-03 Confirm booking

| state | when |
|-------|------|
| default | summary |
| slot taken | 409 slot_taken on create |

### S-04 Booked

| state | when |
|-------|------|
| success | booking made |

## 4. Navigation

S-01 slot -> S-02 -> S-03 Confirm booking -> S-04 -> My bookings (existing tab).
S-03 slot taken -> S-01.
