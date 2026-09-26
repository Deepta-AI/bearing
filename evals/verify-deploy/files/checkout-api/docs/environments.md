# Environments

No secrets in this file, ever: no tokens, passwords, API keys, signed URLs
or `user:pass@` in a URL. It is committed and read by agents. Checks are GET
requests with no credentials, so every path listed here must answer without
signing in. The agent never deploys or rolls back; the Rollback row is a
sentence for the engineer, not a command anyone runs from here.

Version field: `json:<dotted.path>` for a JSON body or `header:<Name>` for a
response header; it must carry the deployed commit or tag.

## qa

| Key | Value |
| --- | --- |
| Product URL | https://qa.checkout-api.invalid |
| API base URL | https://api.qa.checkout-api.invalid |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | checkout-team |
| Rollback | Re-run the deploy job of the previous tag's pipeline in GitLab (Deployments, qa, Rollback); it takes about four minutes. |
| Synthetic suite | - |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| basket page | product | /basket | 200 | Your basket |
| public price list | api | /v1/prices | 200 | - |

## prod

| Key | Value |
| --- | --- |
| Product URL | https://checkout-api.invalid |
| API base URL | https://api.checkout-api.invalid |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | checkout on-call |
| Rollback | Promote the previous image tag in the prod Argo CD app; the on-call lead approves. |
| Synthetic suite | - |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| basket page | product | /basket | 200 | Your basket |
