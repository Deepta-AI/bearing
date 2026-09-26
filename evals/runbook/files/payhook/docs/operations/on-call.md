# On-call

- Primary: the `payments-oncall` rotation in PagerDuty. Every payhook alert
  with `severity: page` goes here.
- Secondary: the `payments-secondary` rotation. Page it when the primary has
  not recovered the service within 30 minutes, or at once for anything that
  loses payment events.
- Incident channel: `#inc-payments`. Open it for any page that lasts more
  than 15 minutes.
- Orders API problems: page the `orders-oncall` rotation; payhook cannot fix
  a slow or failing Orders API.
- Card provider problems (their outage, a signing secret rotation): the
  provider's support portal, reached from the payments vault entry
  "provider-support". Secrets live in the vault, never in chat or docs.
  The portal can redeliver our webhooks for any time window up to 72 hours
  back; redelivered events carry a fresh signature.

Postmortems: any page that lost or delayed payment events by more than 30
minutes needs one within five working days, under `docs/incidents/`.
