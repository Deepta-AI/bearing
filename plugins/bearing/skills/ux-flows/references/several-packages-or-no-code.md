# ux-flows: a product with several packages, or no code yet

Read when: the product has no handlers yet, no visitor accounts, or more than one flow package.

- No handlers yet (a green-field product designed contract first): the
  API contract is what ships. Read each operation's error codes and
  response descriptions as its rejections, and head the ledger "from the
  contract, no code yet"; the limits come from the data model and the
  HLD. A conflict is then between the stories and the contract.
- No visitor accounts (a marketing site): the session walk covers the
  anonymous visitor and, where it exists, the staff sign-in; it does not
  invent account states the product does not have.
- One package per feature, one id space: screen ids continue from the
  previous package (the admin area starts after the public site's last
  id) and never repeat; the gate refuses an id two packages share.
- Site-wide stories (performance, accessibility, search, the design
  system) map to no screen. List them under "Site-wide, no screen of its
  own" with the sections that carry them (the state copy, the interaction
  inventory); they are not unmapped.
- Page chrome (header, footer, language switch, consent banner) is one
  group in the interaction inventory, "every page", not repeated per
  screen.
- Many rejections: one error row per rejection, labelled with its code
  (`error: slot_unavailable`); the recovery flows may group a screen's
  error rows by operation, each row named in the flow.
