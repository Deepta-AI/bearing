# Leaked secret: <name>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This record is
     the written trail of one leak response: revoke, rotate, scrub, audit,
     notify, in that order, all times in UTC. It is read by the security
     contact, the owner and any auditor later. Never paste the value, a
     prefix or a redacted form of it; name the secret and its type only.
     The field table: every row filled with a time and a name. Revoked comes
     before Rotated; the scrub command is the one printed for the engineer,
     who ran it (the agent never rewrites history or pushes).
     Example: | Revoked | 09:14Z at SendGrid console by Arjun M. | -->

| Field | Value |
| --- | --- |
| Detected | <YYYY-MM-DD HH:MM>Z by <who or scanner> |
| Type | <api key / ...> |
| Where it leaked | <commit sha, file, CI log, chat, other> |
| First exposed | <commit sha, date> (`git log --all -- <path>`) |
| Revoked | <HH:MM>Z at <provider> by <name> |
| Rotated | <HH:MM>Z; services redeployed: <list> |
| Scrubbed | <HH:MM>Z, command: `<history rewrite command>`, run by <name>; force-push and re-clone notice sent <HH:MM>Z |

## Blast radius

<!-- What: how long the secret was exposed, where copies went and what it
     could reach, from `git log --all --oneline -- <path>` and the provider's
     audit log.
     Good: counts, not adjectives ("exposed: N commits, M places"); forks,
     clones, CI caches and chat are listed even after the rewrite, because a
     rewrite does not reach them; "Evidence of use" quotes the audit log
     result and its time window, or says the log was not available.
     Example: | Evidence of use | SendGrid activity log 2026-08-28 to 2026-08-30: 0 sends from unknown IPs | -->

| Question | Answer |
| --- | --- |
| Commits carrying it | N |
| Remotes, forks, mirrors | <list> |
| CI logs and artefacts | <list or none> |
| Chat, tickets, docs | <list or none> |
| What the secret could reach | <systems, data classes> |
| Evidence of use | <provider audit log result> |

## Timeline (UTC)

<!-- What: every action and decision from detection to the last follow-up,
     in time order.
     Good: HH:MMZ times with the date when it spans days, one action per
     row, and the person who did it; the order shows revoke happened before
     rotate and scrub.
     Example: | 09:02Z | gitleaks pre-commit flagged `config/mail.yml:7` on MR !482 | CI | -->

| Time | Entry | By |
| --- | --- | --- |

## Notified

<!-- What: everyone told about the leak: the owner, the security contact
     from SECURITY.md, the provider when its policy asks, customers when
     their data was reachable.
     Good: a name or team, a UTC time and the channel, so the notice can be
     found again; a party decided against is listed with the reason.
     Example: | security@acme-health.in (SECURITY.md contact) | 2026-08-30 09:40Z | email, ticket SEC-117 | -->

| Who | When | Channel |
| --- | --- | --- |

## Follow-ups

<!-- What: the changes that stop this leak happening again, each with an
     owner, a task id and a due date.
     Good: every row has an owner and a task; the pre-commit scan row stays
     until every clone has the hook; "be more careful" is not an action.
     Example: | Move `SENDGRID_API_KEY` to a masked, protected CI variable | Arjun M. | OPS-231 | 2026-09-06 | -->

| Action | Owner | Task | Due |
| --- | --- | --- | --- |
| Pre-commit scan present on every clone | | | |
