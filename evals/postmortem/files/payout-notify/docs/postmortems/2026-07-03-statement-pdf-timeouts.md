# Postmortem: Statement PDFs missing from payout emails

- Date of incident: 2026-07-03, 52 minutes, sev 3
- Author: payouts on-call; reviewers: payouts team
- Follow-ups: PAY-198, PAY-199

## Summary

Payout emails went out without the statement PDF for 52 minutes on 3 July
because the PDF renderer timed out under the month-end batch. 1,140 partners
got an email with no attachment. Re-sent the statements the next morning.

## Impact

- Emails without the statement: 1,140 (provider export, 18:04Z to 18:56Z)
- Money: none; payouts were unaffected.

## Timeline (UTC)

- 18:00Z batch started
- 18:04Z first email without an attachment (provider export)
- ~18:30Z partner success reported it
- 18:56Z batch finished
- 2026-07-04 04:10Z statements re-sent

## Root cause

A renderer sized for a normal day allowed the month-end volume to queue
behind it, which under the 5 s render timeout produced emails sent without
the attachment instead of failing.

## Follow-ups

| Action | Owner | Task | Due |
| --- | --- | --- | --- |
| Fail the email when the PDF is missing instead of sending without it | payouts-team | PAY-198 | 2026-07-10 |
| Size the renderer for month-end volume | platform-team | PAY-199 | 2026-07-17 |

## Lessons

- An email that goes out incomplete is worse than one that goes out late.
