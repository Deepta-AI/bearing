# Data needs: members

## S-01 Members

### Fields

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-01 | member.email | string | server | exists |

### Actions

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-01 | Send invite | create an invite | 201 created; 409 already_member | new |
| A-03 | Load members | list the members | 200 members | exists |

### States

| State | Server condition |
| --- | --- |
| loading | the member list request is in flight |
| empty | the list returns zero members |
| error: already_member | the invite call returns 409 already_member |

## S-02 Invite

### Fields

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-02 | invite.expires_at | datetime | server | new |

### Actions

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-02 | Revoke | revoke the invite | 204 revoked | exists |

### States

| State | Server condition |
| --- | --- |
| loading | the invite request is in flight |
| error | the send call fails with a 5xx or a timeout |
