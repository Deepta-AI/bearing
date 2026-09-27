# PRD: Shift swaps

Owner: Product, rostering. Target release: 1.4.

## Problem

Staff swap shifts over chat and managers find out after the fact. Swaps
that break the statutory rest rule reach payroll unnoticed.

## Requirements

| Id | Statement | Priority |
| --- | --- | --- |
| REQ-001 | A staff member can ask to take over a colleague's future shift. | Must |
| REQ-002 | The ward manager approves or rejects each swap, giving a reason when rejecting. | Must |
| REQ-003 | A swap that leaves anyone fewer than 11 hours rest between shifts is blocked. | Must |
| REQ-004 | Both staff members get an email when a swap is approved. | Should |
| REQ-005 | Every swap state change is kept in an audit trail that HR can read. | Must |
| REQ-006 | withdrawn: 2026-08-30, payroll reads swaps directly. Approved swaps are exported to payroll nightly. | Could |

## Out of scope

- Swapping between wards.
- Open shift marketplace.
