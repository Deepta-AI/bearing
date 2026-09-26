# Incident severity

Severity is set from user impact, decided by the incident lead, and
re-read at every update. When two levels fit, take the higher one and
say why. Severity goes up during an incident when impact widens; it
comes down only at resolve.

| Sev | Impact | Examples | Response | Comms cadence | Postmortem |
| --- | --- | --- | --- | --- | --- |
| 1 | A core journey is down or data is at risk for most users | payments fail, login down, data loss or exposure, security breach | page on-call lead and service owner now, lead and comms are two people, war room open | internal every 30 min, status page at declare and every 30 min, customer note within 1 h | required, 5 working days, reviewed by the lead group |
| 2 | A core journey is degraded, or a secondary journey is down, for many users | p95 over 3 s on checkout, search down, one region failing, exports broken | page on-call lead now, war room open | internal every hour, status page at declare and hourly, customer note at resolve | required, 5 working days |
| 3 | A journey is impaired for some users, or a workaround exists | a report page errors for one tenant, notifications delayed, a flag left on | on-call handles in working hours, lead informed | internal at declare and resolve, status page only if a customer would notice | required, lightweight (one page) |
| 4 | No user impact yet; an alert fired or a risk was found | disk at 80 percent, certificate expiring in 10 days, a flapping probe | ticket with a due date, no war room | none beyond the ticket | none; the ticket is the record |

## Deciding questions

1. Can users complete the journey they came for? No for most users is
   sev 1; slowly or with retries is sev 2; no for a few is sev 3.
2. Is money or data involved? A failed payment, a double charge, a
   leak or a loss is sev 1 regardless of user count.
3. Is there a workaround a support agent can give in one sentence? Then
   at most sev 3.
4. Is it getting worse? A rising error rate rounds up one level.
5. Is it security? Anything touching auth, tokens, PII or access rounds
   up to sev 1 until the security lead says otherwise.

## What severity does not depend on

- The alert's own label. `warning` alerts have started sev 1 incidents.
- The time of day. A sev 1 at 3 a.m. is a sev 1.
- Who noticed. A customer report and a monitor firing carry the same
  weight; the customer report usually means the monitor is missing, a
  follow-up in itself.
- The cause. Severity is impact; cause is the postmortem's job.
