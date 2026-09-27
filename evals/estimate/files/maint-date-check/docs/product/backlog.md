# maintdesk v1 backlog

Built from PRD v1.0, updated for PRD v1.1 after the client review on
2026-10-01. Story ids are referenced from tests, commits and the tracker,
so they never change; a dropped story stays here marked withdrawn. Points
use the team's scale: 1, 2, 3, 5, 8.

| Story | Title | Priority | Points | Status |
| --- | --- | --- | --- | --- |
| US-01-001 | Tenant reports a repair | Must | 5 | Done (sprint 1) |
| US-01-002 | Tenant sees request status | Must | 3 | Done (sprint 1) |
| US-01-003 | withdrawn: Tenant and vendor chat | Could | | Withdrawn |
| US-01-004 | Landlord assigns a vendor | Must | 5 | Done (sprint 2) |
| US-01-005 | Vendor gets an SMS for a new job | Must | 5 | Done (sprint 2) |
| US-01-006 | Landlord sees job times per vendor | Should | TBD | To do |
| US-01-007 | Vendor is paid when the job is closed | Must | 5 | To do |
| US-01-008 | Tenant rates the vendor | Should | 2 | Done (sprint 3) |
| US-01-009 | Tenant attaches photos to a request | Must | 3 | To do |
| US-01-010 | Landlord closes a job | Must | 3 | Done (sprint 3) |
| US-01-011 | Landlord gets a weekly open-jobs email | Could | 2 | To do |
| US-01-012 | Vendor gets new jobs as push notifications | Should | TBD | To do |
| US-01-013 | Landlord downloads a monthly statement | Must | TBD | To do |
| US-01-014 | Monthly payout ledger per landlord | Must | TBD | To do |
| US-01-015 | Vendor sees their payout history | Should | TBD | To do |

## US-01-001 Tenant reports a repair
Status: Done (sprint 1)   Priority: Must   Points: 5
Covers: REQ-001   Depends on: none

- AC-US-01-001-1: Given I am a tenant, when I describe a problem in at
  least 10 characters and send, then an open request is created.
- AC-US-01-001-2: Given a description under 10 characters, when I send,
  then it is refused with a message.

## US-01-002 Tenant sees request status
Status: Done (sprint 1)   Priority: Must   Points: 3
Covers: REQ-002   Depends on: US-01-001

- AC-US-01-002-1: Given my request, when I open it, then I see its status
  and history.
- AC-US-01-002-2: Given someone else's request, when I open it, then I see
  nothing.

## US-01-003 withdrawn: Tenant and vendor chat
Withdrawn with REQ-010 after the client review (sprint 2).

## US-01-004 Landlord assigns a vendor
Status: Done (sprint 2)   Priority: Must   Points: 5
Covers: REQ-003   Depends on: US-01-001

- AC-US-01-004-1: Given an open request, when I pick a vendor, then the
  request is assigned to them.
- AC-US-01-004-2: Given an assigned request, when I pick a vendor again,
  then I am refused.

## US-01-005 Vendor gets an SMS for a new job
Status: Done (sprint 2)   Priority: Must   Points: 5
Covers: REQ-004   Depends on: US-01-004

- AC-US-01-005-1: Given a request is assigned, then the vendor receives an
  SMS with the job number and description.

## US-01-006 Landlord sees job times per vendor
Status: To do   Priority: Should   Points: TBD
Covers: REQ-009   Depends on: US-01-010

- AC-US-01-006-1: Given closed jobs, when I open Vendors, then each vendor
  shows the median days from assignment to close over the last 90 days.
- AC-US-01-006-2: Given a vendor with fewer than 3 closed jobs, then their
  time shows as "not enough jobs".
- AC-US-01-006-3: Given I pick a vendor, then I see their closed jobs with
  the days each took.

## US-01-007 Vendor is paid when the job is closed
Status: To do   Priority: Must   Points: 5
Covers: REQ-006   Depends on: US-01-010

- AC-US-01-007-1: Given an assigned job with an agreed amount, when the
  landlord closes it, then a payout of that amount is requested for the
  vendor.
- AC-US-01-007-2: Given a payout is confirmed by PayGate, then the job
  shows Paid with the payout reference.
- AC-US-01-007-3: Given a payout fails, then the landlord sees the failure
  and can retry.
- AC-US-01-007-4: Given a vendor whose beneficiary verification is not
  complete, when the job is closed, then no payout is attempted and the
  landlord is told why.

## US-01-008 Tenant rates the vendor
Status: Done (sprint 3)   Priority: Should   Points: 2
Covers: REQ-007   Depends on: US-01-010

- AC-US-01-008-1: Given my job is closed, when I open it, then I can rate
  the vendor from 1 to 5 once.
- AC-US-01-008-2: Given a job that is not closed, then no rating is
  offered.

## US-01-009 Tenant attaches photos to a request
Status: To do   Priority: Must   Points: 3
Covers: REQ-008   Depends on: US-01-001

- AC-US-01-009-1: Given I am reporting a repair, when I attach up to 5
  photos, then they are saved with the request.
- AC-US-01-009-2: Given a photo over 8 MB, then it is refused with a
  message.
- AC-US-01-009-3: Given an assigned request, when the vendor opens the job
  link from the SMS, then they see the photos.
- AC-US-01-009-4: Given a photo, when it is saved, then location data in
  it is removed.
- AC-US-01-009-5: Given I am the vendor on a job, when I finish, then I can
  attach up to 5 "after" photos. (added at the client review)
- AC-US-01-009-6: Given a job, when the landlord opens it, then they see
  the tenant's and the vendor's photos side by side. (added at the client
  review)
- AC-US-01-009-7: Given a job closed 90 days ago, then its photos are
  deleted. (added at the client review)

## US-01-010 Landlord closes a job
Status: Done (sprint 3)   Priority: Must   Points: 3
Covers: REQ-005   Depends on: US-01-004

- AC-US-01-010-1: Given an assigned job, when I close it, then it shows
  Closed with the date.
- AC-US-01-010-2: Given an open job, when I try to close it, then I am
  refused.

## US-01-011 Landlord gets a weekly open-jobs email
Status: To do   Priority: Could   Points: 2
Covers: REQ-011   Depends on: none

- AC-US-01-011-1: Given it is Monday 08:00, then each landlord with open
  jobs gets one email listing them with their age.
- AC-US-01-011-2: Given a landlord with no open jobs, then no email is
  sent.

## US-01-012 Vendor gets new jobs as push notifications
Status: To do   Priority: Should   Points: TBD
Covers: REQ-004   Depends on: US-01-005

Asked for at the client review: vendors miss SMS among spam.

- AC-US-01-012-1: Given a vendor has the maintdesk Android app, when a job
  is assigned to them, then they get a push notification instead of the
  SMS.
- AC-US-01-012-2: Given the push is not delivered within 5 minutes, then
  the SMS is sent.

## US-01-013 Landlord downloads a monthly statement
Status: To do   Priority: Must   Points: TBD
Covers: REQ-012   Depends on: US-01-014

- AC-US-01-013-1: Given a month with payouts, when I download the
  statement, then I get a PDF listing each job, vendor, amount and payout
  reference.
- AC-US-01-013-2: Given a month with no payouts, then the statement says
  so.

## US-01-014 Monthly payout ledger per landlord
Status: To do   Priority: Must   Points: TBD
Covers: REQ-012   Depends on: US-01-007, US-01-013

The ledger's fields follow the statement layout, so it waits for the
statement.

- AC-US-01-014-1: Given a confirmed payout, then it is recorded in the
  landlord's ledger for the month it was confirmed.
- AC-US-01-014-2: Given a failed payout, then it is not in the ledger.

## US-01-015 Vendor sees their payout history
Status: To do   Priority: Should   Points: TBD
Covers: REQ-013   Depends on: US-01-007

- AC-US-01-015-1: Given payouts to me, when I open Payouts from the link
  in my SMS, then I see each job, amount, date and status.
