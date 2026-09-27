# Payments (updated 1 September 2026)

The checkout service (another repository) creates a payment link at the
provider for an open invoice and records the provider's reference in
`payment_events` as a `kind = 'link_created'` event, with the reference in
`payload->>'reference'`. About 9,000 links are created a day. A link
expires 14 days after it is created; an invoice gets a new link (and a new
reference) only after the old one expired.

When the customer pays, the provider calls `POST /webhooks/payment-paid`
with the reference only. It retries for 72 hours until it gets a 2xx and
never calls again after that.

BILL-231 moves the reference onto the invoice: from this release the
checkout service calls `Store.SetExternalRef` when it creates a link, and
the paid webhook finds the invoice with `Store.FindByExternalRef`. The
`link_created` events keep being written.
