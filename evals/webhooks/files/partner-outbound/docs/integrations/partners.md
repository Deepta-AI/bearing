# Partner call notes (2026-09-19)

Attendees: Acme Resellers, BlueCart, our integrations team.

- Both want order.shipped and order.cancelled pushed to an HTTPS
  endpoint they give us, so they can stop polling every minute.
- Acme's endpoint goes down for planned maintenance most Sundays,
  usually 02:00 to 06:00 IST. They do not want to lose events sent in
  that window.
- BlueCart said their endpoint answers 400 for payloads it cannot
  parse, and asked us not to keep resending those.
- BlueCart asked for a way to see which events we sent them and whether
  they succeeded, and to resend one, because their last supplier's
  answer to "did you send it?" was always "we think so".
- Both will verify that a request really came from us.
- Acme applies events in the order they arrive. An order can be
  cancelled after it has shipped (the parcel is recalled); if Acme gets
  order.cancelled before order.shipped for the same order, their system
  ships it again.
- From October partners will enter and change their own endpoint URL in
  the partner portal; today our team sets it.
