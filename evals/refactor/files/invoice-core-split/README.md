# invoicing

Builds, numbers and renders invoices for the counter app. Amounts are whole
paise (integers) everywhere.

## Public API

Two other services import this package directly, so these names are a
contract:

    from invoicing.core import Invoice, LineItem, compute_totals, compute_tax, render_text

The export job loads the renderer by dotted path from
`invoicing/settings.py` (`RENDERER`), so that path must keep resolving.

## Tax

GST per region comes from `TAX_RATES` in `invoicing/core.py`. Tax is worked
out per line and rounded half up to the paisa. A region with no rate falls
back to Karnataka and logs a warning.

## Running

    make check        # compile + tests
    python3 -m invoicing.cli --ledger sample/ledger.txt "PEN-01|Gel pen|3|2500"

The CLI reads the last invoice number from the ledger file and issues the
next one.

## Operations

`ops/alerts.yaml` is loaded by the log pipeline. The tax-rate alert matches
on the logger name and the message prefix.
