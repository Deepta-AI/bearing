# .bearing/company.json

Each adopting repository keeps its team facts in `.bearing/company.json`.
Skills read these keys; a skill never ships a value for them. When a key
is absent, the skill asks once or leaves that step out, and says which.

| Key | Holds | Example |
|---|---|---|
| `tracker.prefix` | ticket key prefix | `"OPS"` |
| `chat.incident_channel` | where incidents and hotfixes are announced | `"#ops-incidents"` |
| `deploy.prod` | the command a developer runs to deploy production | `"make deploy ENV=prod"` |
| `oncall.rota` | link to the on-call rota | `"https://example.invalid/rota"` |

A skill that needs a new key adds a row here in the same change.
