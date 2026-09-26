# customers-api

Customer profiles and addresses for the shop apps and partners.
Contract: `api/openapi.yaml`. Versioning and deprecation policy:
`docs/api/API_LIFECYCLE.md`.

Logs:
- `logs/app/`: this service's own application log.
- `logs/gateway/`: access logs from the API gateway, one file per
  month, one JSON object per line; closed months are gzipped.

    make check   # go vet and go test
