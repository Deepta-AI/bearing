# invoicing

Issues GST invoices and credit notes, renders them to PDF, exports them
as CSV for finance, charges cards through the payment gateway and
receives the gateway's signed webhooks.

    make check    # compile and run the tests (quarantined tests excluded)

Technical debt is tracked in `docs/DEBT.md` and reviewed monthly.
Quarantined tests are listed in `docs/testing/quarantine.md`; each has a
deadline by which it is fixed or deleted. Ownership is in `CODEOWNERS`.
