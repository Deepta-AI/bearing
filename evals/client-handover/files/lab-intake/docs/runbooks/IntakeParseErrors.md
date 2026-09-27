# Runbook: IntakeParseErrors

Last verified: 2026-02-10

1. Find the lab sending bad payloads: `kubectl -n lab-intake logs deploy/lab-intake | grep "missing"`.
2. Ask the lab to correct the payload; the parser does not accept partial reports.
3. Once fixed, the lab re-sends; nothing needs replaying on our side.
