# Flows: payout approvals

Status: signed off in the design review, 18 Sep 2026. Written against PRD v1.1.

## 1. Screens

| id | screen | job |
|----|--------|-----|
| S-01 | Approvals queue | See what is waiting and open the most urgent payout |
| S-02 | Payout detail | Check one payout and approve it |
| S-03 | Reject payout (dialog over S-02) | Reject with a reason the vendor will read |

## 2. Interaction states

### S-01 Approvals queue

| state | when | copy |
|-------|------|------|
| loading | first load, page change | (skeleton rows) |
| empty | nothing waiting | "Nothing to approve. Payouts waiting for you will show up here." |
| error | list call failed | "Payouts did not load. Check your connection and try again." + Retry |
| success | one page of payouts | table: Vendor, Invoice, Amount, Due, Status |
| partial | more than one page (25 per page) | pager under the table: "Showing 1 to 25 of 61" |

### S-02 Payout detail

| state | when | copy |
|-------|------|------|
| loading | opening a payout | (skeleton) |
| empty | n/a, a payout always has content | |
| error | detail call failed | "This payout did not load. Try again." + Retry |
| success | status pending | Approve payout (primary), Reject (secondary) |
| approved | after Approve | toast "Payout to <vendor> for <amount> approved", back to S-01 |

### S-03 Reject payout

| state | when | copy |
|-------|------|------|
| default | dialog open | Title "Reject payout", field "Reason", button "Reject payout" |
| submitting | after submit | button shows "Rejecting..." and is disabled |
| error | reject call failed | "The payout was not rejected. Try again." |

## 3. Events

No analytics events for this feature yet.

## 4. Navigation

| from | control | to |
|------|---------|----|
| sidebar | Payouts | S-01 |
| S-01 | a payout row | S-02 |
| S-02 | Back to approvals | S-01 |
| S-02 | vendor name | Vendor profile |
| S-02 | Reject | S-03 |
| S-03 | Reject payout (success) | S-01, toast "Payout rejected. The vendor has been emailed." |
| S-03 | Cancel | S-02 |

## 7. Open questions

None.
