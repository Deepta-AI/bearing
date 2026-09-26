# claimdesk backlog

Built from PRD v1.0 (2026-09-12). Sprint 1 closed 2026-09-19; sprint 2
runs to 2026-10-03. Story ids are referenced from tests, commits and the
tracker, so they never change; a dropped story stays here marked
withdrawn.

Definition of done for every story with a screen: meets WCAG 2.1 AA
(REQ-014) and works in a phone browser (REQ-004, REQ-005 read as mobile
web under ADR-0002, see Q-3).

| Story | Title | Covers | Status |
|-------|-------|--------|--------|
| CLM-1 | Record a claim with its receipt | REQ-001, REQ-002, REQ-003 | Done (sprint 1) |
| CLM-2 | Submit a claim; small claims approve themselves | REQ-009 | Done (sprint 1) |
| CLM-3 | Manager approves or rejects a claim | REQ-007, REQ-008, REQ-015 | Done (sprint 1) |
| CLM-4 | See the status of my claims | REQ-006 | To do |
| CLM-5 | Employee is emailed when a claim is decided or paid | REQ-011 | In progress (sprint 2) |
| CLM-6 | withdrawn: Slack alerts for managers | REQ-013 | Withdrawn |
| CLM-7 | Download my monthly PDF statement | REQ-006 | To do |
| CLM-8 | Link each employee to their manager | inferred (needed by REQ-007, REQ-012, REQ-016) | Done (sprint 1) |
| CLM-9 | Finance pays approved claims in bulk | REQ-010 | To do |
| CLM-10 | Manager is emailed when a claim waits for them | REQ-012 | In progress (sprint 2) |
| CLM-11 | Finance decides for an absent manager | REQ-016 | To do |

## CLM-1 Record a claim with its receipt
As an employee, I want to record an expense with a photo of its receipt
right after I spend, so I am not chasing paper later. (B2)

- AC-1: Given I am signed in, when I enter date, amount, category and
  description and save, then a draft claim appears in my list.
- AC-2: Given a draft, when I attach a JPEG, PNG or PDF receipt, then it
  shows on the claim.
- AC-3: Given a receipt over 10 MB, when I attach it, then it is refused
  with "Receipts can be up to 10 MB".

## CLM-2 Submit a claim; small claims approve themselves
As an employee, I want to submit a claim and have small ones approved at
once, so I am paid sooner. (B1)

- AC-1: Given a draft with a receipt, when I submit, then its status is
  Submitted.
- AC-2: Given a draft under INR 2,000, when I submit, then its status is
  Approved with no manager step.
- AC-3: Given a draft with no receipt, when I submit, then it is refused.

## CLM-3 Manager approves or rejects a claim
As a manager, I want to decide my reports' claims with the receipt in
view, so I approve what I can see. (B1)

- AC-1: Given a submitted claim from my report, when I open it, then the
  receipt shows beside the details.
- AC-2: Given a submitted claim, when I approve, then its status is
  Approved.
- AC-3: Given a submitted claim, when I reject without a reason, then the
  rejection is refused until I give one.
- AC-4: Given a claim from someone who does not report to me, when I try
  to decide it, then I am refused.

## CLM-4 See the status of my claims
As an employee, I want to see where each claim is, so I do not have to
ask finance. (B1)

- AC-1: Given I have claims, when I open My claims, then each shows its
  status and, once paid, the payment date.

## CLM-5 Employee is emailed when a claim is decided or paid
As an employee, I want an email when a claim is approved, rejected or
paid, so I know without checking. (B1)

- AC-1: Given my claim is rejected, when the manager saves, then I get an
  email with the reason.
- AC-2: Given my claim is approved or paid, then I get an email saying so.

## CLM-6 withdrawn: Slack alerts for managers
Withdrawn with REQ-013 in the v1.0 review (moved to a later release).

## CLM-7 Download my monthly PDF statement
As an employee, I want a monthly PDF of all my claims, so I can check them
against my payslip. (B1)

- AC-1: Given claims in a month, when I download that month's statement,
  then the PDF lists each claim with amount, status and payment date.

## CLM-8 Link each employee to their manager
As a finance admin, I want each employee linked to their manager, so
claims go to the right approver. (inferred; B1)

- AC-1: Given an employee with a manager set, when they submit a claim
  over the threshold, then only that manager can decide it.

## CLM-9 Finance pays approved claims in bulk
As a finance admin, I want to see every approved claim and mark a batch
paid after the payroll run, so staff are paid in one go. (B1)

- AC-1: Given approved claims, when I open Pay claims, then all approved
  claims are listed with owner and amount.
- AC-2: Given I select claims and mark them paid with a date, then each
  shows Paid with that date.

## CLM-10 Manager is emailed when a claim waits for them
As a manager, I want an email when a claim is waiting for me, so it does
not sit unseen. (B1)

- AC-1: Given a report submits a claim over the threshold, then I get an
  email naming the claimant and amount.

## CLM-11 Finance decides for an absent manager
As a finance admin, I want to approve or reject for a manager who is away,
so claims do not wait on one person. (B1)

- AC-1: Given a manager marked away, when I decide their report's claim,
  then the decision is saved and records that I decided on their behalf.

## Open questions
| Id | Question | Decision | Status |
|----|----------|----------|--------|
| Q-1 | PRD says auto-approve under INR 2,000; code and FP-12 said 500. | Finance revised FP-12 to 2,000 on 2026-09-15; code changed. | Closed |
| Q-2 | REQ-017 (CSV export) contradicts the PRD's out-of-scope list. | Left out of v1 until product confirms; no story. | Open |
| Q-3 | REQ-004 and REQ-005 name native apps; ADR-0002 rules them out for 2026. | Read as mobile web; covered by the definition of done. | Open |
