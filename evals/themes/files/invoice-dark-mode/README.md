# invoice-web

The browser client for the invoicing product: invoice list, invoice
editor, revenue chart and account settings. React 18 with Vite. The API
lives in another repository.

## Conventions

- Colours come from the custom properties in `src/styles/tokens.css`.
  Components use `var(--color-...)`, never a literal colour.
- User preferences (density, and anything like it) go through
  `src/lib/prefs.js`. Do not call `localStorage` directly: it throws in
  Safari private windows and in the embedded webview one of our
  accounting integrations uses, and the app must still load there.
- Invoices are printed and saved as PDF with the browser's print dialog
  (`window.print()` from the invoice view). `src/styles/print.css` makes
  the printed page match the paper invoice; customers send these to
  their own clients, so a printed invoice is always black on white.
- `index.html` carries the Content-Security-Policy agreed in the
  public-sector security review. Any change to it goes back through
  that review, so it is not changed as part of feature work.
- Accessibility: we sell to public-sector buyers whose contracts require
  WCAG 2.1 AA. Text needs 4.5:1 against its background, UI edges and
  focus rings 3:1.

## Commands

    make check    # node --test: unit tests for src/lib (no install needed)

`pnpm install` and `pnpm dev` need the network; CI runs the Vite build.
