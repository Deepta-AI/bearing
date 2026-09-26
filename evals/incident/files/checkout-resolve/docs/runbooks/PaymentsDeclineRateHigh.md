# PaymentsDeclineRateHigh

Fires when more than 5 percent of card payment attempts are declined for 5
minutes (`monitoring/alerts.yaml`). Normal decline rate is 1 to 2 percent.

## Diagnosis

1. Check the gateway status page (https://status.gateway.example.test). If
   the gateway reports an incident, go to Remediation 3.
2. Open the payments dashboard, panel "Declines by code". One code
   dominating (for example `auth_failed` or `3ds_required`) points at our
   request rather than at customers' cards.
3. Check what was released recently: `git tag -l --sort=-creatordate | head -3`
   and the tag dates.

## Remediation

1. A release in the last two hours: roll it back.
   `make rollback VERSION=<previous tag>`
   Confirm: decline rate under 2 percent on the dashboard within 10 minutes
   of the rollout finishing.
2. The 3DS flow is suspected: turn it off. Set `CHECKOUT_3DS_V2=false` in
   `config/production.env` and run `make config-apply`.
   Confirm: no `3ds_*` codes in "Declines by code" within 5 minutes.
3. Gateway incident: nothing to roll back. Post on the status page and
   follow the gateway's updates.
