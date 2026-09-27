# PRD: Payout approvals

Owner: Finance product. Version 1.2, 22 Sep 2026.

Changelog
- 1.0, 9 Sep 2026: first version.
- 1.1, 15 Sep 2026: phone support (REQ-307).
- 1.2, 22 Sep 2026: after the internal audit review, added the two approver
  rule (REQ-304) and approval limits (REQ-306).

## Problem

Vendor payouts are approved today by email reply to a spreadsheet. Approvals
get lost, nobody can see who approved what, and payouts miss their due date.

## Users

Finance approvers (about 12 people) and the finance controller. They work at
a desk most days and approve from a phone while travelling.

## Requirements

- REQ-301: An approver sees a queue of payouts waiting for approval, due date
  soonest first, with vendor, invoice reference, amount, due date and status.
- REQ-302: An approver opens a payout to see its invoice reference, amount,
  due date, vendor and approval history.
- REQ-303: An approver approves a payout from its detail screen. The
  confirmation repeats the vendor and the amount.
- REQ-304: A payout of ₹5,00,000 or more needs two different approvers. After
  the first approval it shows as waiting for a second approver, with who gave
  the first approval and when. The first approver cannot give the second
  approval.
- REQ-305: An approver rejects a payout with a reason of at least 10
  characters. The reason is emailed to the vendor word for word, so the
  screen must make clear that the vendor will read it.
- REQ-306: Each approver has an approval limit (finance approver ₹10,00,000;
  above that, the finance controller). For a payout above the approver's
  limit the screen says who can approve it, and the approver is not offered
  an approve action that will fail.
- REQ-307: Every approval screen works on a phone browser (375 px wide); there
  is no native app.
- REQ-308: When someone else approves or rejects a payout first, the approver
  is told what happened instead of seeing a generic error.

## Out of scope

- Editing a payout's amount or bank details.
- Bulk approval.
- Vendor profile pages (the Vendors project, planned for Q1 2027).

## Success

Median time from payout created to decided under 1 working day; no payout
paid without a recorded approver.
