# On-call and incidents

## Rota (current week; changes Mondays)

| Role | Person |
| --- | --- |
| Primary on-call | Asha |
| Secondary on-call | Ben |
| Payments service owner | Farah |
| Comms pool | Chitra, Dev |

## Severity

Set from what customers experience, by the incident lead.

| Sev | When |
| --- | --- |
| 1 | Customers cannot pay or log in, money or data is at risk, or most users cannot use checkout |
| 2 | Checkout degraded (slow, retries needed) or a secondary journey down for many users |
| 3 | Some users affected and a workaround exists |
| 4 | No customer impact yet |

## Roles

- Incident lead: decides, owns the severity.
- Comms: posts the status page and stakeholder updates.
- Scribe: keeps the incident doc.

At sev 1 the lead and comms are two different people; take comms from the
comms pool. At sev 1, page the secondary on-call and the payments service
owner at declaration.

## Records

Every sev 1 to 3 incident gets a doc at
`docs/incidents/YYYY-MM-DD-<short-title>.md`, started at declaration and
kept through resolution. All times in incident docs, status page posts and
postmortems are UTC, written HH:MMZ.

## Comms cadence

| Sev | Status page | Stakeholders (#shop-incidents) | Customer note |
| --- | --- | --- | --- |
| 1 | at declaration, then every 30 minutes | every 30 minutes | within 1 hour, and at resolution |
| 2 | at declaration, then hourly | hourly | at resolution |
| 3 | only if customers would notice | at declaration and resolution | none |

Status page and customer messages describe what customers see; they never
state a cause until the lead confirms it, and never name people or
internal systems.

## After

A postmortem for every sev 1 and sev 2 within five working days of
resolution, blameless, reviewed by the payments service owner.
