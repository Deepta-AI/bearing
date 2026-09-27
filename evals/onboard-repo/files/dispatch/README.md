# dispatch

Delivery dispatch: a Go API that estimates delivery times and a Python worker
that assigns deliveries to riders.

    services/api      Go HTTP API (POST /v1/eta)
    services/worker   Python assignment worker

## Tests

From the repository root:

    go test ./...
    pytest
