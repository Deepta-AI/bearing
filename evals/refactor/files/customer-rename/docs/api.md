# Billing API

## GET /clients/{id}

200:

    {"client_id": "c_102", "name": "Meera Textiles", "plan": "pro", "active": true, "monthly_paise": 249900}

404:

    {"error": "client not found"}

The mobile app (v3 and later) shows its "account missing" screen by
matching the exact error string above; do not reword it without a mobile
release.

## GET /healthz

200 `ok`.

## Metrics

`/debug/vars` exposes `billing_clients_active` (gauge). The finance
dashboard in `ops/dashboard.json` charts it.

## Logs

Every request logs `client_id` and `remote` (the caller IP). Support
searches logs by `client_id`.
