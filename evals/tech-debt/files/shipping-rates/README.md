# shipping-rates

Quotes parcel shipping prices by weight and destination PIN code, and
renders the 4x6 shipping label for each booked parcel. The API layer
lives in another repository and calls `rates.quote.build_quote` once per
request inside a long-running worker process.

## Layout

- `src/rates/`: zones, carrier base rates, the fuel surcharge, quotes
- `src/labels/`: label rendering
- `vendor/barcode128/`: a vendored copy of an upstream Code 128 encoder;
  we do not edit it, we replace it when upstream releases
- `config/surcharges.json`: the fuel surcharge, edited by ops without a deploy
- `docs/`: changelog and team notes

## Working on it

    make check    # compile and run the tests

Ownership is in `CODEOWNERS`.
