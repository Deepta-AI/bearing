# The build host has no internet access. Every Go command resolves modules
# from the mirror snapshot in third_party/goproxy (docs/adr/0003).
export GOPROXY := file://$(CURDIR)/third_party/goproxy
export GONOSUMDB := mods.example.com
export GOTOOLCHAIN := local

.PHONY: check vet test build vuln go

check: vet test

vet:
	go vet ./...

test:
	go test ./...

build:
	go build -o bin/api ./cmd/api

# Vulnerability scan.
vuln:
	govulncheck ./...

# Any other go command with the mirror settings, e.g. make go ARGS="list -m -u all"
go:
	go $(ARGS)
