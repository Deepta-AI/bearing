# Open questions: Kettle Street Rewards

PRD: docs/product/PRD.md   Updated: 2026-09-24
Entries: 7   Open: 3   Needs your confirmation: 1

## Needs your confirmation

- Q-004 How fast must a till scan be? Assumed: under 2 seconds from scan to the member shown on the till (REQ-007).

## Register

| Q | Status | Kind | Where | Basis | Question | Readings | Decision | Why | Affects |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q-004 | open | open-question | REQ-007 | assumption | How fast must a till scan be? | (a) under 1 s; (b) under 2 s; (c) under 5 s | (b) under 2 seconds | 90 bills an hour per till leaves about 40 s a bill | REQ-007 |
| Q-001 | confirmed | contradiction | REQ-008 | stated | The brief says a free coffee every 5th visit, but 18 points a visit needs 6 visits for 100 points. | (a) keep 100 points (6th visit); (b) 90 points (5th visit) | (a) keep 100 points; show progress to the next drink | client marketing lead, 2026-09-24 | REQ-008, REQ-016 |
| Q-002 | confirmed | contradiction | REQ-010 | stated | Do points expire? Brief item 5 says 12 months; the call notes say never. | (a) 12 months; (b) never | (a) 12 months | client marketing lead, 2026-09-24 | REQ-010 |
| Q-003 | confirmed | contradiction | REQ-009 | stated | The birthday reward needs a date of birth, which ADR-0003 does not allow. | (a) drop the reward; (b) seek DPO sign-off | (a) drop for launch | client marketing lead, 2026-09-24 | REQ-009 |
| Q-005 | confirmed | gap | REQ-002 | stated | What does a refund do to points? | (a) remove the points; (b) keep them | (a) remove them (REQ-017) | client operations head, 2026-09-24 | REQ-002, REQ-017 |
| Q-006 | open | open-question | REQ-014 | stated | Daily report by email or a dashboard? | (a) email; (b) dashboard | not decided | the call left it open | REQ-014 |
| Q-007 | open | open-question | REQ-015 | stated | What makes the app feel premium? | (a) brand fonts and colours only; (b) a design review by the brand agency | not decided | the brief gives no measure | REQ-015 |
