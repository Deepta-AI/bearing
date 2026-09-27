# Invoices: flows

## Invoice list (`list`)

Job: show the studio owner who owes them money, and let them start a new invoice.
Primary action: New invoice.

States:

- loaded: the table of invoices, newest first; columns number, client, due, amount, status.
- empty: "No invoices yet. Send your first one and it will show up here." with the New invoice button.
- loading: skeleton rows in the table's shape.
- error: "We couldn't load your invoices. Check your connection and try again." with a Try again button.

## Invoice detail (`detail`)

Job: show one invoice and whether it has been paid; send a reminder if not.
Primary action: Send reminder (only when unpaid).

States:

- unpaid: summary, line items, Send reminder, Delete invoice.
- delete-confirm: "Delete INV-0042? This can't be undone." with Delete and Cancel.
