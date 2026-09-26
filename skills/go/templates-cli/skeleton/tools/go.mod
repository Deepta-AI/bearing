// Developer tools, pinned by the tool directive (Go 1.24 and newer). A module
// of its own so their dependencies stay out of the tool's go.mod, go.sum,
// govulncheck scan and binary. `make tools` installs every tool below into
// bin/tools at these versions, the same versions the go-api stack pins. Bump
// one with `go -C tools get -tool <package>@<version>` and commit
// tools/go.sum.
module __MODULE__/tools

go 1.26.8

tool (
	github.com/golangci/golangci-lint/v2/cmd/golangci-lint
	golang.org/x/vuln/cmd/govulncheck
)

require (
	github.com/golangci/golangci-lint/v2 v2.13.2
	golang.org/x/vuln v1.8.0
)
