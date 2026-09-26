# Security

## Reporting a vulnerability

Report a vulnerability in Bearing itself (a hook that can be bypassed, a
script that leaks a credential, a template that ships an insecure
default) through the repository's private vulnerability reporting (on
GitHub: the Security tab, then "Report a vulnerability"). Do not open a
public issue for it. Expect an acknowledgement within two working days and a fix
or a mitigation within thirty.

## What Bearing protects, and how

- Credentials never enter the repository or the conversation. They live
  in `~/.config/bearing/bearing.env` (mode 600); the tracker adapters read
  it and pass tokens through curl config on a file descriptor, never on
  the command line; `brg-tracker config` prints only whether a token is
  set.
- The agent never publishes. `bin/brg-guard` blocks push, history
  rewrites, merges, releases, package publishing and deployment
  commands. It fails closed: a command it cannot read is refused. Claude
  Code hooks, the per-harness adapters written by `bin/brg-harness` and
  the repository's `.claude/settings.json` deny list all derive from the
  same verb table (`brg-guard --verbs`).
- A push needs a person. The `pre-push` git hook asks for the branch name
  on the terminal; without a terminal it refuses, and CI must set both
  `CI=true` and `BEARING_PUSH_CONFIRMED=1` to bypass.
- The repository settings template denies reading secrets, keys,
  keystores, lockfiles and cloud credentials, and denies the third-party
  skills that import browser cookies, send code to other models or
  deploy.
- Secret scanning runs in `pre-commit` (common token shapes) and in CI
  (the host's secret detection job).

## Scope

Vulnerabilities in third-party packs installed by the installer belong to
their maintainers (see `docs/THIRD_PARTY.md`); tell us anyway so Bearing
can pin or drop the pack.
