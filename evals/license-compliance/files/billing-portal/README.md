# billing-portal

Invoices, usage charts and PDF downloads for the billing team. Runs as our
hosted service and, since 1.3.0, as a Docker image that on-prem customers
pull and run on their own servers (see docs/adr/0003-on-prem-image.md).

## Run

    npm ci
    make check        # unit tests
    npm start         # needs CONFIG_PATH pointing at a config.yml

## Dependencies

All our dependencies are MIT or similarly permissive (audited March 2025).
chart-lite draws the usage charts and is MIT; invoice-pdf renders the
invoice PDFs.
