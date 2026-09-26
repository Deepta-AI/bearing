# kettle-loyalty

Loyalty programme for Kettle Street Cafes (14 company outlets). This repository
holds the service that listens to the till (POS) webhooks and keeps each
member's points balance. The customer app is a separate repository.

## Layout

- `src/loyalty/` the webhook handler and the members store
- `tests/` pytest suite, `make check` runs it
- `docs/adr/` architecture decisions
- `docs/briefs/` what the client sent us, kept as received; do not edit
- `docs/product/` product documents; the PRD lives at `docs/product/PRD.md`

## Working agreement

Every requirement in the PRD carries an id (REQ-nnn). Stories, tests and
commits cite those ids, so an id is never reused or renumbered once written.
Anything the client has not confirmed is written down as a question for them,
not as a requirement.

## Running

    make check
