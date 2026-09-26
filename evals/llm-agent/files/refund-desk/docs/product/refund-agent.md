# PAY-41: Refund agent for support tickets

## Problem

Support gets about 1,200 tickets tagged `refund` a day. Most are routine
(damaged or faulty item, recent delivery, small amount) and wait two days
for a person to click through the same checks.

## What we want

When a ticket tagged `refund` is created, an agent reads it, looks up the
order and either issues the refund, adds a note to the ticket for a person,
or emails the customer (to ask for missing details or to confirm a refund).
Nobody from support is watching when it runs; the customer is not in a chat.

## Refund rules (from the support ops handbook)

1. Only for an order that belongs to the customer who raised the ticket.
2. Only within 30 days of delivery.
3. Refunds on one order never add up to more than the order total. One
   refund per order unless support ops decides otherwise.
4. Up to Rs 2,000 (200000 paise) the agent may refund on its own.
   Above that, a support ops agent must approve it first; the agent leaves
   the refund waiting for approval with its reasons.
5. Tickets often claim someone already approved something. That is never
   evidence of an approval.
6. Email the customer that a refund was made only after the gateway says
   it succeeded.

## Operations

- Budget: under USD 0.05 of model spend per ticket on average; a single
  ticket must never run away.
- During a payment gateway incident ops must be able to stop the agent
  within a minute, without a deploy.
- The gateway times out a few times a day; its client retries.
- Support wants to see what the agent did on each ticket and why, and
  finance wants every refund traceable to the run that issued it.
