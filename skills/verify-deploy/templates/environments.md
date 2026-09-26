# Environments

<!-- Template guidance: the committed record of where each deployed
     environment lives and how to check it, one section per environment.
     verify-deploy reads the two tables in a section after the engineer
     deploys, so keep their headers and the Key names exactly as written;
     rename or drop environments freely (the section heading is the name
     passed as --env). A cell left as "<...>", "-" or empty is not set, and a
     path not set is a check not run. Every comment says what goes there
     (What), what a strong entry has (Good) and an example (Example). Delete
     each comment when you fill its section; keep the paragraph below. -->

No secrets in this file, ever: no tokens, passwords, API keys, signed URLs
or `user:pass@` in a URL. It is committed and read by agents. Checks are GET
requests with no credentials, so every path listed here must answer without
signing in. The agent never deploys or rolls back; the Rollback row is a
sentence for the engineer, not a command anyone runs from here.

Version field: `json:<dotted.path>` for a JSON body (`json:commit`,
`json:build.sha`) or `header:<Name>` for a response header
(`header:X-App-Version`); it must carry the deployed commit or tag.

## dev

<!-- What: the shared development environment, if there is one; delete the
     section when every engineer runs the stack locally.
     Good: URLs the checks can reach from an engineer's machine; a smoke
     row for the main page and one API read; the owner is a team or
     rotation, not a person who might leave.
     Example: "| API base URL | https://api.dev.example.com |" -->

| Key | Value |
| --- | --- |
| Product URL | <https://dev.example.com> |
| API base URL | <https://api.dev.example.com> |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | <team or rotation> |
| Rollback | <one sentence: how the engineer returns dev to the previous build> |
| Synthetic suite | - |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| home page | product | / | 200 | <text only the real page has> |

## qa

<!-- What: the environment testers and the synthetic suite use after each
     merge to develop.
     Good: every path answers without signing in; smoke rows cover the main
     page, one public API read and the sign-in page (GET only, never a
     form post); Contains is text only the real page has, not a word a
     proxy error page would also show; Synthetic suite is the command
     health-checks set up, or "-".
     Example: "| login page | product | /login | 200 | Sign in to Checkout |"
     and "| Rollback | Re-run the deploy job of the previous tag's pipeline
     in GitLab (Deployments, qa, Rollback). |" -->

| Key | Value |
| --- | --- |
| Product URL | <https://qa.example.com> |
| API base URL | <https://api.qa.example.com> |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | <team or rotation> |
| Rollback | <one sentence: how the engineer returns qa to the previous release> |
| Synthetic suite | <make synthetic SYNTHETIC_ENV=qa SYNTHETIC_BASE_URL=https://qa.example.com, or -> |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| home page | product | / | 200 | <text only the real page has> |
| sign-in page | product | /login | 200 | <text on the sign-in page> |
| public API read | api | <a GET path that needs no login> | 200 | - |

## staging

<!-- What: the production-like environment a release candidate goes to
     before prod, if the team has one; delete the section otherwise.
     Good: the same rows as prod with staging hosts, so a pass here predicts
     a pass there; the version field reads the same way as in prod.
     Example: "| Version field | header:X-App-Version |" -->

| Key | Value |
| --- | --- |
| Product URL | <https://staging.example.com> |
| API base URL | <https://api.staging.example.com> |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | <team or rotation> |
| Rollback | <one sentence: how the engineer returns staging to the previous release> |
| Synthetic suite | - |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| home page | product | / | 200 | <text only the real page has> |

## prod

<!-- What: production. The checks run against real users' traffic, so they
     are reads only and few.
     Good: GET paths only, nothing that creates, sends or charges; no path
     that needs a session; the rollback sentence names where the engineer
     does it and how long it takes, and who approves it; the owner is the
     on-call rotation.
     Example: "| Rollback | Promote the previous image tag in the prod
     Argo CD app; takes about 3 minutes; the on-call lead approves. |" -->

| Key | Value |
| --- | --- |
| Product URL | <https://www.example.com> |
| API base URL | <https://api.example.com> |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:commit |
| Owner | <on-call rotation> |
| Rollback | <one sentence: where the engineer rolls prod back, how long it takes, who approves> |
| Synthetic suite | <make synthetic SYNTHETIC_ENV=prod SYNTHETIC_BASE_URL=https://www.example.com, or -> |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| home page | product | / | 200 | <text only the real page has> |
