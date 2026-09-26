---
name: verify-deploy
description: 'Checks one environment after the engineer deploys: readiness, health, version, smoke pages, synthetic suite; read-only, never rolls back. Use when asked to "verify the deploy", "check qa after deploying".'
argument-hint: "<env> [deployed commit or tag]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(git describe:*), Bash(git tag -l:*), Bash(git log:*), Bash(git rev-parse:*), Bash(python3 *skills/verify-deploy/scripts/verify_deploy.py*), Bash(/usr/bin/python3 *skills/verify-deploy/scripts/verify_deploy.py*), Bash(make synthetic:*), Bash(make -n synthetic:*)
---

# verify-deploy

The engineer deploys; this skill checks what landed. One committed file
says where each environment lives and what "up" means there, so the check
after a deploy is the same list every time, in the same order, with a
report that counts what it examined. It reads over GET only and never
deploys, redeploys, rolls back or writes to a server.

Not this: `health-checks` builds `/healthz`, `/readyz` and the
synthetic suite this skill calls; `release` prepares the version
and the tag before the deploy; `incident` takes over when a failed
check is already hurting users.

## Inputs

- environment: `$1` (`dev`, `qa`, `staging`, `prod` or any section name
  in the file); if absent, ask once which environment was deployed.
- environments file: `docs/environments.md`; if absent, copied from
  `templates/environments.md` and the run stops for the engineer to fill
  it (step 1). Never guess a URL from `.env.example`, the README, CI
  variables or a naming pattern.
- expected version: `$2`, the commit or tag the engineer says was
  deployed. If absent, find how the environment is deployed (README, CI
  file): an environment deployed from tags may use the latest tag from
  `git describe --tags --abbrev=0`, said so; an environment deployed from
  a branch (qa from develop, say) has no tag to compare, and neither the
  latest tag nor this checkout's HEAD is what went out. Then ask once for
  the commit or tag; still none: run without `--expect` and say the
  version was read, not compared.
- the checker: `scripts/verify_deploy.py` in this skill, python3 standard
  library only.
- synthetic suite: the file's "Synthetic suite" row for the environment;
  run when it is a `make synthetic` target (`make -n synthetic` resolves),
  printed for the engineer otherwise; `-` or absent: `n/a`.
- watch window: gstack `/canary` for prod ("Canary after deploy" in the
  workflow map); gstack not installed: say so and name the dashboards the
  owner watches instead.
- sandbox: the repository template's `.claude/settings.json` turns the
  Bash sandbox on with `allowUnsandboxedCommands: false` and a fixed
  `sandbox.network.allowedDomains`, which holds registries and loopback,
  not the team's hosts. See step 3.

## Steps

1. File. When `docs/environments.md` is missing, Read
   `templates/environments.md` and Write it to `docs/environments.md`
   unchanged, then stop: "docs/environments.md created from the template;
   fill the <env> section (product URL, API base URL, paths, version
   field, owner, rollback sentence) and run verify-deploy again".
   When the section for the environment is missing or its URLs are still
   `<...>` placeholders, stop the same way naming the rows to fill. Where
   the repository shows where a value lives without holding it (a CI
   job's `environment: url: $QA_URL`, a Helm values key), say where to
   look; the variable's name is a pointer, never a URL to try. The
   file holds no secrets: a URL with `user:pass@` in it, a token in a
   query string or a signed URL is removed and the engineer told why.
2. Version. Resolve the expected commit or tag as in Inputs. Print
   "expected <version> (from: the engineer | latest tag | not given)".
3. Sandbox. Read `.claude/settings.json`. When `sandbox.enabled` is true,
   the environment's hosts (from the Product URL and API base URL rows)
   must be in `sandbox.network.allowedDomains`, or every check fails with
   a connection error that says nothing about the deploy. Missing hosts:
   print the snippet for the engineer to add to their own
   `.claude/settings.local.json`, which is git-ignored; Claude Code
   combines its list with the shared one:
   ```
   { "sandbox": { "network": { "allowedDomains": ["qa.example.com", "api.qa.example.com"] } } }
   ```
   then stop until they confirm, or offer the checker command for them to
   run in their own terminal and paste back. The agent never edits
   either settings file and never runs the check outside the sandbox
   (`allowUnsandboxedCommands` is false by design). No sandbox (the
   setting absent or false): the check runs directly; say so.
4. Check, in order (readiness, health, version, smoke):
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/verify-deploy/scripts/verify_deploy.py" --env <env> --expect <version>`
   with `--file docs/environments.md --out docs/releases/` as defaults,
   `--timeout 10`, `--retries 2`. GET only, at most 3 redirects, retries
   only on connection errors and 502, 503, 504. A python3 without the ssl
   module cannot check https: the checker stops before any request and
   writes no report; rerun it with a python3 that has ssl (`/usr/bin/python3`
   often does), never with the result of the one that could not. Its last line
   `verify: N checks, F failed (env <env>, deployed <version>)` is the
   evidence. N of 0 exits 1: the section defines no check, so nothing was
   verified; fill a path and rerun. It writes
   `docs/releases/verify-<env>-<UTC date and time>.md`. A `reach:` line
   appears when any check got no answer. One report of record per run:
   a report this run wrote that describes a local fault (the interpreter,
   a proxy, a typo in the command) rather than the environment is deleted
   by the run that wrote it, or marked superseded in its first line, and
   the final message names the one that counts. Reports from earlier runs
   are history: never edited, never cited as today's result.
5. Synthetic suite, when the row names a make target:
   `make synthetic SYNTHETIC_ENV=<env> SYNTHETIC_BASE_URL=<product URL>`
   and its tail as evidence; a non-make command is printed for the
   engineer, not run. A synthetic failure fails the verdict like a check.
6. Prod only: suggest gstack `/canary` with the product URL for a watch
   window of 10 to 30 minutes; the checks above are one moment, the
   canary sees the traffic after it.
7. Verdict. Pass: every check and the synthetic suite passed. Fail: a
   host answered and a check failed; list each failed check with its
   expected and got, then the environment's Rollback sentence from the
   file, quoted, as the engineer's decision. Unverified: no check got an
   answer (a connection error or DNS failure on every one). That is not
   evidence the deploy is broken, and neither the report nor the message
   calls the environment down, broken or failed. Name the likely causes
   first (DNS, the VPN or network the check ran from, the sandbox's
   allowed domains, a wrong or placeholder hostname in the file), offer
   the checker command for the engineer to run from a network that
   reaches the hosts, and quote the Rollback sentence only as what applies
   if a check still fails once a host answers. The agent never rolls
   back, redeploys, restarts or scales anything, and never retries the
   deploy.
8. Print the output contract, then report in the four headings (Changed,
   Verified, Not done, Noticed): Changed is the report file (and
   `docs/environments.md` when it was created); Verified carries the
   `verify:` line verbatim and the synthetic tail; Not done names the
   failed checks and the rollback left to the engineer, or "not run" for
   a step that did not run.

## Output contract

```
## Deploy verification: <env> (expected <version | not given>, deployed <version | unknown>)
| Check | URL | Expected | Got | ms | Result |
| readiness | https://api.qa.example.com/readyz | 200 | 200 | 41 | pass |
...
<verify: N checks, F failed (env <env>, deployed <version>), verbatim>
Synthetic: make synthetic (env <env>): passed | failed (<tail>) | printed for the engineer | n/a
Sandbox: hosts allowed | snippet printed, run by the engineer | no sandbox
Canary: gstack /canary suggested (prod) | n/a
Report: docs/releases/verify-<env>-<UTC>.md
Verdict: pass | fail (F failed: <checks>) | unverified (no host answered; causes to rule out first)
Rollback (the engineer's call): "<sentence from docs/environments.md>"
```

## Gotchas

- The agent never deploys, rolls back or redeploys. A failed check ends
  with the rollback sentence for the engineer, not an action; bin/brg-guard
  blocks the deploy verbs anyway.
- The evidence is HTTP from the file, not the cluster. The agent runs no
  `kubectl`, `helm`, `argocd` or pipeline command, read-only ones
  included: the local kube context is whatever the engineer last used and
  may be another cluster, so `kubectl get pods` can answer confidently
  about the wrong place. When pod state would help (every check got a
  503, say), print the read-only command for the engineer
  (`kubectl --context <qa context> -n <namespace> get pods`,
  `rollout status`, `logs`) with the context and namespace left for them
  to confirm; never `apply`, `rollout undo`, `restart`, `scale`,
  `delete`, `helm upgrade|rollback` or `argocd app sync`.
- A post-deploy step in a README or Makefile that writes to the
  environment (seeding data, a test order, a cache warm) is not a check.
  It is left for the engineer and named in Not done, even when the doc
  says to run it after every deploy.
- `/healthz` passing says the process is up, not that the new version is.
  The version check is the one that proves the deploy landed; without a
  version endpoint, add one (`health-checks` step 2) before
  trusting a pass.
- A smoke check whose Contains text is a generic word ("OK", "Welcome")
  passes on a proxy's error page. Pick text only the real page has.
- A load balancer can keep serving the old build for a minute after the
  deploy finishes. A version mismatch right after a deploy is worth one
  rerun after a short wait before calling it a failure; say that it was
  rerun.
- A commit matches by prefix of at least 7 characters; a tag matches
  exactly, so `v1.4` does not match `v1.4.0`.
- Readiness 503 retries twice with a short backoff, then fails. A
  readiness check that flaps between runs is a finding for
  `health-checks`, not a reason to raise the retries.
- The file is committed and read by agents: no tokens, passwords, basic
  auth in URLs or signed links, ever. A smoke path that needs a session
  does not belong in it.
- A prod smoke check is a GET a user could make. Nothing that creates an
  order, sends a message or charges a card, even as a probe.
