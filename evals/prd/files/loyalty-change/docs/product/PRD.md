# PRD: Kettle Street Rewards

Source: docs/briefs/loyalty-brief.md (email 2026-09-18 and kickoff call notes 2026-09-21), client answers of 2026-09-24   Normalised: 2026-09-24
Owner: client marketing lead   Tracker epic: LOY-1

## 1. Problem

Repeat visits are down: 31% of customers returned within 30 days last
quarter, against 44% a year before (brief, "Why"). Paper stamp cards get lost
and staff stamp cards for friends (brief, "Why").

## 2. Business objectives

| Id | Objective | Target (measurable) | Source |
| --- | --- | --- | --- |
| B1 | Customers come back more often | target: unconfirmed | brief, "What we want to achieve" |
| B2 | Members scan at the till | 40% of weekly till customers scan a member QR by 31 Mar 2027 | brief, "What we want to achieve" |
| B3 | Stamp-card fraud stops | target: unconfirmed | brief, "What we want to achieve" |

## 3. Non-goals

- Paper stamp cards are not kept alongside the app (brief, "Why").

## 4. Personas

| Persona | Group | Who they are | What they need | Source |
| --- | --- | --- | --- | --- |
| Member | 00 end user | a cafe customer who has joined | earn and redeem points | brief, "How it works" |
| Barista | 02 operator | till staff | scan members without slowing the queue | brief, "For our staff" |
| Outlet manager | 01 admin | runs one outlet | daily member visit count | brief, "For our staff" |

## 5. Requirement statements

One testable statement per id. Ids are never reused or renumbered.

### 5.1 Joining and earning

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-001 | The system enrols a customer by mobile number verified with a one time password. | Member | brief, item 1 | none |
| REQ-002 | The system credits 1 point for every Rs 10 of a completed bill linked to a member. | Member | brief, item 2 | none |
| REQ-017 | The system removes the points a bill earned when that bill is refunded. | Member | Q-005 answer, 2026-09-24 | none |
| REQ-003 | The app shows the member's current points balance. | Member | brief, item 8 | none |
| REQ-004 | The app shows the member's points history. | Member | brief, item 8 | none |

### 5.2 At the till

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-005 | The app shows a QR code that identifies the member. | Member | brief, item 3 | none |
| REQ-006 | The till scan of a member QR links the bill to that member. | Barista | brief, item 3 | none |
| REQ-007 | The till scan completes fast enough not to slow the morning queue. | Barista | brief, "For our staff" | ambiguous: Q-004 |

### 5.3 Rewards

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-008 | The system lets a member redeem 100 points for one free drink of any size. | Member | brief, item 4 | none |
| REQ-018 | A member can redeem from the day they join, with no minimum membership period. | Member | call notes, marketing lead | none |
| REQ-009 | The system gives a member a free pastry on their birthday. | Member | brief, item 6 | withdrawn: conflicts with ADR-0003, Q-003 |
| REQ-010 | Points expire 12 months after they are earned. | Member | brief, item 5; Q-002 | none |
| REQ-011 | The system credits 50 bonus points to a referring member when the friend they referred makes a first purchase. | Member | brief, item 7 | none |
| REQ-012 | The system credits 50 bonus points to the referred friend on their first purchase. | Member | brief, item 7 | none |

### 5.4 Outlet staff

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-013 | The system counts the members who visited each outlet each day. | Outlet manager | brief, "For our staff" | none |
| REQ-014 | The outlet manager receives the daily member visit count for their outlet. | Outlet manager | brief, "For our staff"; call notes | ambiguous: Q-006 |

### 5.5 App

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-015 | The app feels premium, in line with the brand. | Member | brief, "Look and feel" | ambiguous: Q-007 |
| REQ-016 | The app shows how many points the member needs for their next free drink. | Member | Q-001 answer, 2026-09-24 | none |

## 6. Constraints

- The one time password is sent over WhatsApp (brief, item 1).
- Budget for the first version: Rs 12 lakh (brief, "Money and time").
- Live in all 14 outlets by 26 October 2026 (brief, "Money and time").
- Member personal data is limited to phone number and first name (ADR-0003).
- The loyalty service and app take no payments (ADR-0002).
- Morning rush 07:30 to 10:00, about 90 bills an hour per till (call notes).

## 7. Open questions

7 entries in docs/product/questions.md: 3 open, 1 needs your confirmation (Q-004).

## 8. Could not extract

- Non-goals beyond the stamp cards: the client marketing lead can confirm.

## 9. Glossary

| Term | Meaning | Source |
| --- | --- | --- |
| Till | the POS terminal at the counter | brief |
