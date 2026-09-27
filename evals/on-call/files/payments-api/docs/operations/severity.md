# Severity scale (storefront engineering)

Used by every storefront team. Changes go through the storefront
engineering leads, not a single team.

| Sev | Meaning | Who is notified | When |
| --- | --- | --- | --- |
| 1 | Customers cannot pay or data is at risk | page the on-call engineer | any hour |
| 2 | Payments degraded for many customers, workaround exists | page the on-call engineer | business hours only (09:00 to 19:00 Asia/Kolkata, Monday to Friday); outside them, first thing the next business morning |
| 3 | Minor, few customers affected | team alert channel | next business day |
| 4 | Cosmetic or internal only | ticket | backlog |

Alert rules carry the label `severity: page` for Sev 1, `critical` for Sev 2,
`warning` for Sev 3 and `ticket` for Sev 4.
