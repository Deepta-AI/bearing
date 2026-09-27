# Backlog: Shift swaps

## EP-01 Shift swaps

### US-01-001 Request a swap

As a staff member I want to ask for a colleague's shift so that I can
cover it.

- Covers: REQ-001
- Ticket: SHF-11
- Events: `swap_requested`

Acceptance criteria:

- AC-US-01-001-1: Requesting a colleague's future shift creates a pending swap.
- AC-US-01-001-2: Requesting your own shift is refused.
- AC-US-01-001-3: Requesting a shift that has already started is refused.

### US-01-002 Manager decides a swap

As a ward manager I want to approve or reject swaps so that the roster
stays safe.

- Covers: REQ-002
- Ticket: SHF-12

Acceptance criteria:

- AC-US-01-002-1: A pending swap can be approved or rejected once.
- AC-US-01-002-2: A rejection without a reason is refused.

### US-01-003 Enforce the rest rule

As a ward manager I want swaps that break the 11 hour rest rule blocked so
that we stay compliant.

- Covers: REQ-003
- Ticket: SHF-13
- Events: `swap_blocked_rest_rule`

Acceptance criteria:

- AC-US-01-003-1: A swap leaving fewer than 11 hours rest is blocked.
- AC-US-01-003-2: The rule holds when the rest period crosses midnight.

### US-01-004 Approval email

As a staff member I want an email when my swap is approved so that I know
to turn up.

- Covers: REQ-004
- Ticket: SHF-14
- Events: `swap_approved`

Acceptance criteria:

- AC-US-01-004-1: Both staff members receive an email within 5 minutes of approval.

### US-01-005 Bulk swaps

Status: withdrawn: 2026-09-02, managers asked for single swaps only.

As a ward manager I want to swap a whole week in one go.

- Ticket: SHF-15

Acceptance criteria:

- AC-US-01-005-1: A manager can select up to seven shifts to swap.
- AC-US-01-005-2: One rejected shift rejects the whole bulk swap.
