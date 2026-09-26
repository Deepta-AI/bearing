# refunds

Refund service for the support desk. Support agents create refunds
through the API; support leads can also load a day's refunds from the
desk's CSV export with `refunds-bulk <file.csv>`. A worker sends approved
refunds to Razorpay.

## Running

    make run      # starts the API on :8090

Configuration comes from environment variables; see `.env.example`.

## Layout

- `src/refunds/` the service
- `tests/` unit tests (`make check`)
- `docs/refunds.md` the refund rules
