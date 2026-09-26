# Test cases: reminders

| Id | Covers | Case | Expected |
| --- | --- | --- | --- |
| TC-0011 | REQ-201 | appointment booked 3 days out | one 24h and one 2h reminder job exist |
| TC-0012 | REQ-204 | appointment cancelled after jobs written | no SMS is sent at run_at |
| TC-0013 | REQ-205 | patient has sms_opt_out = true | no SMS is sent |
| TC-0014 | REQ-203 | MSG91 answers 429 | job is marked failed and not retried |
| TC-0015 | REQ-203 | MSG91 answers 500 | job is marked failed |
