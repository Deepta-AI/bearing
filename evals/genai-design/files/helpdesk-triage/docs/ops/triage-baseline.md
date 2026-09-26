# Routing baseline (March audit)

Support leads re-checked 400 tickets from 3 to 14 March against the queue
the rules picked.

| Outcome | Tickets | Share |
| --- | --- | --- |
| Routed to the right queue by the rules | 284 | 71% |
| No rule matched, fell to `general`, routed by hand | 72 | 18% |
| Routed to the wrong queue | 44 | 11% |

A ticket routed by hand takes a lead about 4 minutes. A misrouted ticket
waits on average 3.5 hours longer for a first response.

Most misroutes are billing versus invoicing (customers use the words
interchangeably) and integration errors reported as bugs.

The enterprise priority lane is not part of the audit: it comes from the
CRM tier flag and is always right when the sender's domain is known.

A labelled sample of the audit is in `data/audit_march.jsonl` (the
`correct_queue` field is the lead's answer, `rules_queue` is what the
rules picked). The emails are real and still contain customer email
addresses and phone numbers.
