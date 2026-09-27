# orders-api

Public HTTP API for partner integrations: list and fetch orders.
Partners authenticate with an API key in the `X-API-Key` header.

## Running

```
make run          # listens on ADDR, default :8080
make check        # gofmt, go vet, go test
```

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `ADDR` | `:8080` | listen address |
| `RATE_LIMIT_ENABLED` | `true` | turn the per-key rate limiter off without a code change |

## Rate limiting

Each API key may make 120 requests per minute. Over the limit the API
answers `429 Too Many Requests` with a `Retry-After` header. Set
`RATE_LIMIT_ENABLED=false` to switch the limiter off.
