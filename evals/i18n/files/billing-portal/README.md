# billing-portal

The customer-facing portal where our business customers see and pay their
invoices. React 18 with Vite; it talks to the billing API under `/api`
(see docs/api.md).

Amounts arrive from the API in paise (integer minor units) and are
formatted in the browser. All our customers are in India.

    make check     # node --test over test/*.test.js (src/lib only)
    pnpm dev       # the app, after pnpm install

Decisions live in docs/adr/.

Hindi: our translation vendor returned its first batch in
`translations/hi-IN.batch1.csv` (human translated and reviewed on their
side). It is keyed by the English source text we sent them in August.
