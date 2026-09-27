# filedrop

Multi-tenant file sharing API. Each customer (tenant) uploads files,
downloads them and hands out share links to people outside the tenant.

- `cmd/api`: the HTTP server.
- `internal/auth`: login and the signed session cookie.
- `internal/files`: upload, list, download and preview.
- `internal/share`: public share links (`/s/{token}`).
- `deploy/k8s`: the production manifests (namespace `filedrop`).

Run the checks with `make check`. Local run: copy `.env.example` to `.env`,
fill it in and `make run`.

Security: see `SECURITY.md` and `docs/security/`.
