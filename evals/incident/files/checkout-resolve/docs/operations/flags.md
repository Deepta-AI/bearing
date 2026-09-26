# Feature flags

Flags are environment variables set in `config/production.env` and applied
with `make config-apply` (CI only). A flag listed as a kill switch is safe to
turn off at any time during an incident.

| Flag | Default | Kill switch | What it does |
| --- | --- | --- | --- |
| `CHECKOUT_3DS_V2` | false | yes | sends card payments through the 3DS v2 challenge flow |
| `GATEWAY_TIMEOUT_S` | 15 | no | gateway call timeout in seconds |
