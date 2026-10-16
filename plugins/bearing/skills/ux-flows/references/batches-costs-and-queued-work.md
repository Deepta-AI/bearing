# ux-flows: batches, costs and queued work

Read when: a screen takes many items in one input, shows a cost before sending, removes a confirmation or starts work that outlives the screen.

- Removing a confirmation removes its safety. Replace it in proportion:
  the parsed count on the button ("Send 12 invites"), or an undo or quick
  revoke after the send.
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
