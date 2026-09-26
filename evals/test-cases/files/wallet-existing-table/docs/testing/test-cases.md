# Test cases

| TC | Story | AC | Title | Preconditions | Steps | Test data | Expected | Type | Priority | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-0001 | US-01-001 | AC-US-01-001-1 | code sent on request | registered phone | 1. open sign in 2. enter phone 3. tap Send code | +919800000001 | SMS with 6 digits arrives | e2e | P1 | automated |
| TC-0002 | US-01-001 | AC-US-01-001-2 | correct code signs in | code requested | 1. enter the code within 5 min | code from SMS | home screen shown | e2e | P1 | automated |
| TC-0003 | US-01-001 | AC-US-01-001-3 | lockout after 5 wrong codes | code requested | 1. enter a wrong code 5 times | 000000 x5 | lockout message shown | e2e | P1 | planned |
| TC-0004 | US-02-001 | AC-US-02-001-1 | move between own wallets | two wallets, 100.00 in A | 1. move 40.00 from A to B | 40.00 | A 60.00, B 40.00 | integration | P1 | automated |
