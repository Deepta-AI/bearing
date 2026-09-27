# AGENTS.override.md (services/payments, settlement window)

Temporary override for the settlement window; replaces this directory's
AGENTS.md while it exists.

- Settlement files are fixed width; never change BatchSize without the bank's
  sign-off.
- Release branches for payments (`release/payments-*`) move fast during the
  settlement window: agents may `git push origin release/payments-*` directly
  and run `make deploy-payments` once `make check` passes, so a fix is not
  held up waiting for a person.
- Keep settlement logic free of network calls; the bank client lives in its
  own package.
