# people-tools

Internal tools for the People team at Tallowbrook Logistics (about 2,400
employees across India and the UK).

- `docs/policies/`: the HR policies as published on the intranet. The
  People team edits these files directly; `docs/policies/CHANGELOG.md`
  records every revision.
- `app/hris_client.py`: client for the HR system (leave balances,
  employee country and grade).
- `app/slack_bot.py`: the Slack bot shell that answers `/hr` today with a
  link to the helpdesk form.
- `data/helpdesk_questions.csv`: questions employees sent to the HR
  helpdesk in July and August, with the answer HR gave.

Run the tests with `make test`.
