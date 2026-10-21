# Flows: Members

## 1. Screen inventory

| Id | Screen | Story | Exits |
| --- | --- | --- | --- |
| S-01 | Members | US-01-001 | Invite to S-02 |
| S-02 | Invite | US-01-001 | terminal |

## 2. Interaction states

### S-01 Members

| State | The user sees | Copy |
| --- | --- | --- |
| loading | skeleton rows | "Members" |
| empty | invitation to add the first member | "No members yet" |
| `error: already_member` | inline banner | "That person is already a member." |
| success | the member list | "Invite sent" |

### S-02 Invite

| State | The user sees | Copy |
| --- | --- | --- |
| loading | disabled form | "Sending" |
| empty | n/a: the form is always shown | |
| error | banner with retry | "Could not send. Retry." |
| success | confirmation | "Invite sent" |

## Task paths

| Task | Story | Kind | Entry | Path | Screens | Interactions | Over |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Invite a member | US-01-001 | primary | S-01 | S-01: tap Invite, tap Send > S-02 | 2 | 2 | |
