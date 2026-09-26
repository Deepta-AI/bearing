# Runbook: CheckoutErrorRateHigh

Fires when the 5xx ratio on `POST /checkout` is above 0.05 for 2 minutes.

## Diagnosis

1. Open the API dashboard, 5xx panel, filtered to shopfront.
2. Check whether the errors are on every pod or one.

## Remediation

1. Restart the checkout pods:

       kubectl -n shop rollout restart deploy/shopfront

   Confirm: the 5xx panel drops under 0.05 within 3 minutes.
2. If the errors persist, page the DBA on-call; the database is the usual
   suspect.

## Escalation

Payments team lead, then the platform on-call.
