# Backlog: purchase orders (release 1)

## US-03-001 Create a purchase order

As a buyer, I want to create a draft purchase order for a supplier so
that I can collect the lines before sending it for approval.

- AC-US-03-001-1: A purchase order has a supplier and one to 50 lines;
  each line has a SKU, a quantity and a unit price. The total is
  computed by the server from the lines, never taken from the client.
- AC-US-03-001-2: If the buyer's app retries a create after a network
  drop, only one purchase order exists afterwards.
- AC-US-03-001-3: A quantity below 1 or above 10,000 is refused, and the
  response says which line and which field was wrong.

## US-03-002 List purchase orders

As a buyer or approver, I want to see my company's purchase orders,
newest first, so that I can find the one I need.

- AC-US-03-002-1: 50 per page by default; the client can ask for fewer.
- AC-US-03-002-2: The list can be filtered by status (draft, submitted,
  approved, cancelled).

## US-03-003 View a purchase order

As a buyer or approver, I want to open one purchase order with its lines
and total.

- AC-US-03-003-1: Someone from another company must not be able to tell
  whether a purchase order id exists.

## US-03-004 Submit for approval

As a buyer, I want to submit a draft purchase order for approval.

- AC-US-03-004-1: Only a draft can be submitted; submitting anything
  else is refused and the purchase order is unchanged.

## US-03-005 Approve a purchase order

As an approver, I want to approve a submitted purchase order so that it
can be sent to the supplier.

- AC-US-03-005-1: Only users with the approver role can approve.
- AC-US-03-005-2: Nobody can approve a purchase order they created.
- AC-US-03-005-3: Approval should be fast.

## US-03-006 Cancel a purchase order

As a buyer, I want to cancel a purchase order I no longer need.

- AC-US-03-006-1: A draft or submitted purchase order can be cancelled.
- Open question (from sprint review, unanswered): can an approved
  purchase order still be cancelled if the supplier has not shipped?

## US-03-007 Export purchase orders to Tally (later release)

As an accountant, I want approved purchase orders exported to Tally.
Not in release 1.
