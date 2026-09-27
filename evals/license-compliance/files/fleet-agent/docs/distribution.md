# Distributing fleet-agent

fleet-agent ships to customers as a single statically linked binary
(`make build`, CGO_ENABLED=0) for linux/amd64 and linux/arm64. Customers
install it on their own hosts from the release tarball, which contains:

- `fleet-agent` (the binary)
- `README.md`
- `THIRD_PARTY_NOTICES.md`

We do not ship source code to customers. Dependencies are vendored under
`vendor/` so a release builds offline from the tagged commit.
