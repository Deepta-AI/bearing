# PRD: Expense claims v1

Version 1.0, 2026-09-12. Owner: Product (internal tools).

## Problem
Staff file expenses on paper forms. Reimbursement takes 21 days on
average, receipts go missing, and managers approve from a pile on their
desk.

## Objectives
| Id | Objective | Measure |
|----|-----------|---------|
| B1 | Pay staff faster | Median submit-to-paid under 7 days |
| B2 | No paper receipts | 100% of claims carry a digital receipt |

## Personas
- Employee: files claims, usually from a phone.
- Manager: approves the claims of their direct reports.
- Finance admin: pays approved claims with the payroll run.

## Statements
| Id | Statement |
|----|-----------|
| REQ-001 | An employee can create an expense claim with the date, amount, category and a short description. |
| REQ-002 | An employee can attach a photo or PDF of the receipt to a claim. |
| REQ-003 | A receipt larger than 10 MB is refused with a message stating the limit. |
| REQ-004 | An employee can submit claims from the iOS app. |
| REQ-005 | An employee can submit claims from the Android app. |
| REQ-006 | An employee can see the status of each of their claims and download a monthly PDF statement of all their claims. |
| REQ-007 | The employee's manager approves or rejects each submitted claim. |
| REQ-008 | A manager must give a reason when rejecting a claim. |
| REQ-009 | Claims under INR 2,000 are approved automatically. |
| REQ-010 | A finance admin sees all approved claims and marks them paid in bulk. |
| REQ-011 | The employee gets an email when a claim is approved, rejected or paid. |
| REQ-012 | A manager gets an email when a claim is waiting for their decision. |
| REQ-013 | withdrawn: Slack notifications for managers (moved to a later release). |
| REQ-014 | Every screen meets WCAG 2.1 AA. |
| REQ-015 | The approver sees the receipt next to the claim details when deciding. |
| REQ-016 | A finance admin can approve or reject on behalf of a manager who is away. |
| REQ-017 | Paid claims are exported each month as a CSV for the accounting system. |

## Out of scope for v1
- Corporate cards and card feeds.
- Mileage calculation.
- Any export or integration with the accounting system; finance keys paid
  claims into it by hand in v1.
- Multi-currency claims.
