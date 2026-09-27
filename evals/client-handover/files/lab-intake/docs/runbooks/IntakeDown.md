# Runbook: IntakeDown

Last verified: 2026-08-30

1. Check the pods: `kubectl -n lab-intake get pods`.
2. If they crash-loop, read the last logs: `kubectl -n lab-intake logs deploy/lab-intake --previous`.
3. A missing variable in the lab-intake-env secret is the usual cause after a deploy; compare it with .env.example.
4. Partner labs retry for 24 hours, so reports sent during the outage arrive again on their own.
