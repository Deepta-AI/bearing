# invoice-api

Issues GST invoices for the billing team and takes the nightly XML export
from the ERP.

| Route | Auth |
|---|---|
| `GET /healthz` | none |
| `GET /invoices`, `POST /invoices` | bearer token |
| `POST /import` | bearer token with role `admin` |

## Building

The build host is offline. Go modules come from the mirror snapshot in
`third_party/goproxy`, which the platform team refreshes weekly
(docs/adr/0003-module-mirror.md). The Makefile exports the settings; for
ad hoc go commands use `make go ARGS="..."` or load `.envrc`.

```
make check    # go vet and go test
make build
make vuln     # vulnerability scan
```

## Dependencies

Internal modules live under `mods.example.com`. Before bumping one, read
docs/adr: some modules are held at a version on purpose.
