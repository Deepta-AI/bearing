# orders-api

Internal service behind the merchant back office. It keeps each tenant's
customers and orders in memory (loaded at start from the nightly snapshot;
in development from a generated seed) and serves the order report that the
back office renders as a table and exports to CSV.

## Endpoints

See docs/api.md.

## Running

    make run                 # listens on :8080, seed sized by SEED_ORDERS / SEED_CUSTOMERS
    make check               # go vet and the tests
    make bench               # report benchmark

Go 1.25, standard library only (docs/adr/0004-stdlib-only.md).

## Service levels

docs/slo.md.
