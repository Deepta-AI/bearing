# ADR-0004: Only admins manage membership

Status: Accepted (2026-06-02)

## Context

Every member on Pro is a paid seat, added automatically when an invite is
accepted. Two support tickets in May came from workspaces billed for seats
nobody with billing responsibility had approved.

## Decision

Only members with the `admin` role can invite people, revoke invites,
remove members or change roles. The API enforces this (`NOT_ADMIN`, 403);
the UI hides the controls from members.

## Consequences

- Members who want a colleague added ask an admin.
- Revisit only together with a seat-approval flow for Pro.
