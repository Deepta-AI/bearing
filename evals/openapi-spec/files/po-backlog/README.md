# procure

Purchase orders for small Indian distributors. A buyer company raises
purchase orders against its suppliers; an approver in the same company
approves them before they go out.

The API is written contract first: the OpenAPI spec is agreed with the
web and mobile teams before any handler is written. `cmd/api` only
serves a health check so far.

    make check   # go vet and go test
