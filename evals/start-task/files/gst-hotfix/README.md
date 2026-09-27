# rates-api

Tax and rate lookups for the invoicing product. Amounts are integer paise;
rates are basis points (1800 bps = 18%).

    make check              # go vet + go test
    go run ./cmd/api        # listens on :8080

GST on a line is rounded half up to the nearest paisa (GST rules round to
the nearest unit; we never round down).

Tickets are in the RATE project of the team tracker. Branching and
releases: RELEASING.md.
