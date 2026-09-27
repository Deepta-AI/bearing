# Checkout backlog

Epics and stories for the checkout service. Once an item is filed in Jira
(project SHOP), its key goes on a `Ticket:` line under the heading.

## Epic E1: Guest checkout

Ticket: SHOP-40

Let people buy without creating an account (ADR-0001).

### CHK-1 Capture a contact email for guest orders

Ticket: SHOP-41

As a guest buyer, I want to give only my email at checkout, so that I can buy
without signing up.

- AC-1.1 Checkout refuses to continue without a valid email.
- AC-1.2 The email is stored on the order in lower case.

### CHK-2 Look up a guest order

Ticket: SHOP-42

As a guest buyer, I want to find my order with my email and order number, so
that I can check its status without an account.

- AC-2.1 Email plus order number returns that order and nothing else.
- AC-2.2 The email match ignores case.

### CHK-3 Address autocomplete for guests

Jira: SHOP-57 (filed from the 10 Sep standup)

As a guest buyer, I want my delivery address suggested as I type, so that I
make fewer typing mistakes.

- AC-3.1 Suggestions appear after three characters.
- AC-3.2 A buyer can ignore suggestions and type any address.

### CHK-4 Turn a guest order into an account

As a guest buyer who has just paid, I want to create an account from the
confirmation page with my order already in it, so that I can track future
orders.

- AC-4.1 The confirmation page offers account creation with the order email
  filled in.
- AC-4.2 The new account owns every earlier guest order with that email.
- AC-4.3 Declining leaves the guest order exactly as it was.

## Epic E2: Saved cards

Let returning customers pay without typing their card again.

### CHK-5 Save a card at checkout

As a returning customer, I want to save my card while paying, so that next
time I do not type it again.

- AC-5.1 Saving is opt-in with an unticked box on the provider's page.
- AC-5.2 We keep the provider token, brand, last four digits and expiry only.

### CHK-6 Pay with a saved card

As a returning customer, I want to pick one of my saved cards at checkout, so
that paying takes one step.

- AC-6.1 Saved cards are listed by brand and last four digits.
- AC-6.2 Paying with a saved card charges through the provider's token API.
- AC-6.3 An expired card is shown but cannot be selected.

### CHK-8 One-click repeat purchase

As a returning customer, I want to repeat a past order in one click, so that
reordering is instant.

- AC-8.1 We keep the card number encrypted (AES-256) in the orders database so
  a repeat order can be charged without the provider's page.
- AC-8.2 The repeat order uses the same delivery address as the original.
