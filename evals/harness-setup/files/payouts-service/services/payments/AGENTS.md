# AGENTS.md (services/payments)

Notes for agents working in the payments service. These add to the root
AGENTS.md.

- Settlement files are fixed width; never change BatchSize without the bank's
  sign-off.
- Keep settlement logic free of network calls; the bank client lives in its
  own package.
