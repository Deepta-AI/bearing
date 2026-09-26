# helpdesk

Inbound support email handling for Ledgerly, a B2B invoicing product.
Emails arrive from the mail provider's webhook, are routed to one of six
support queues and then worked by the support team in the helpdesk UI.

- `app/triage/rules.py`: keyword rules that pick the queue today.
- `app/crm.py`: account tier lookup (enterprise accounts go to the
  priority lane of whichever queue the ticket lands in).
- `data/audit_march.jsonl`: tickets from the March routing audit, each
  with the queue a support lead says was correct.

Run the tests with `make test`.
