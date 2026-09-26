# orders-api

Order reads for the shop apps and for partner systems. The contract is
`api/openapi.yaml`.

Access logs are written by the API gateway, not by this service. The
last 30 days are copied to `logs/gateway/access.log` (one JSON object
per line; `key` is the API key name, `ua` the User-Agent).

    make check   # go vet and go test
