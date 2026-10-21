# ux-flows: a product with several packages, or no code yet

Read when: the product has no handlers yet, no visitor accounts, or more than one flow package; or a screen takes many items in one input, shows a cost or count before sending, or queues work.

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

## Batches, totals and queued sends

- Many items in one input (pasted addresses, uploaded rows): say which
  separators are accepted; normalise the way the server does (trim, case)
  and remove duplicates within the list on that normalised form; show the
  count and any unreadable entries before sending; report the result per
  item from the server's reply, since a check made before sending goes
  stale; let the user retry only the failures without retyping. Per-call
  limits and caps apply per item: say what happens to the ones over.
- Costs and counts before sending: show the unit price, the total for
  what will actually be sent, and when the charge happens. "Actually
  sent" means after duplicates, unreadable entries and everything the
  screen already knows will be refused: existing members and pending
  invites are on the page, so check against them before sending. Label
  that figure as what the page knows now (another admin or an accept
  can change it) and let the per-item server replies set the result.
- Work that outlives the screen: a paced or queued send (rate limit,
  long batch) meets a user who closes the dialog, navigates or loses the
  tab. Say what happens to the items still waiting: kept and resumed,
  or listed as not sent with a way to send them, never dropped silently
  and never shown as sent. A shared window (per workspace) can already
  be partly used by someone else, so pace from the server's refusals,
  not from a client-side count that assumes the first N go through.
