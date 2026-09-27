# maintdesk v1 backlog

Built from PRD v1.0. Story ids are referenced from tests, commits and the
tracker, so they never change; a dropped story stays here marked
withdrawn. Points use the team's scale: 1, 2, 3, 5, 8.

| Story | Title | Priority | Points | Status |
| --- | --- | --- | --- | --- |
| US-01-001 | Tenant reports a repair | Must | 5 | Done (sprint 1) |
| US-01-002 | Tenant sees request status | Must | 3 | Done (sprint 1) |
| US-01-003 | withdrawn: Tenant and vendor chat | Could | | Withdrawn |
| US-01-004 | Landlord assigns a vendor | Must | 5 | Done (sprint 2) |
| US-01-005 | Vendor gets an SMS for a new job | Must | 5 | Done (sprint 2) |
| US-01-006 | Landlord sees job times per vendor | Should | TBD | To do |
| US-01-007 | Vendor is paid when the job is closed | Must | TBD | To do |
| US-01-008 | Tenant rates the vendor | Should | TBD | To do |
| US-01-009 | Tenant attaches photos to a request | Must | TBD | To do |
| US-01-011 | Landlord gets a weekly open-jobs email | Could | TBD | To do |

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
Covers: REQ-009   Depends on: US-01-007

As a landlord, I want to see how long each vendor takes, so I give the
work to the reliable ones. Acceptance criteria to be agreed with the
client; they have not said which times matter.

## US-01-007 Vendor is paid when the job is closed
Status: To do   Priority: Must   Points: TBD
Covers: REQ-006   Depends on: US-01-004

As a vendor, I want to be paid the agreed amount as soon as the landlord
closes my job, so I keep taking jobs from maintdesk. Uses the existing
PayGate client (see README).

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
Status: To do   Priority: Should   Points: TBD
Covers: REQ-007   Depends on: US-01-010

- AC-US-01-008-1: Given my job is closed, when I open it, then I can rate
  the vendor from 1 to 5 once.
- AC-US-01-008-2: Given a job that is not closed, then no rating is
  offered.

## US-01-009 Tenant attaches photos to a request
Status: To do   Priority: Must   Points: TBD
Covers: REQ-008   Depends on: US-01-001

- AC-US-01-009-1: Given I am reporting a repair, when I attach up to 5
  photos, then they are saved with the request.
- AC-US-01-009-2: Given a photo over 8 MB, then it is refused with a
  message.
- AC-US-01-009-3: Given an assigned request, when the vendor opens the job
  link from the SMS, then they see the photos.
- AC-US-01-009-4: Given a photo, when it is saved, then location data in
  it is removed.

## US-01-011 Landlord gets a weekly open-jobs email
Status: To do   Priority: Could   Points: TBD
Covers: REQ-011   Depends on: none

- AC-US-01-011-1: Given it is Monday 08:00, then each landlord with open
  jobs gets one email listing them with their age.
- AC-US-01-011-2: Given a landlord with no open jobs, then no email is
  sent.
