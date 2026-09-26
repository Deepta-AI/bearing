# refunds-api

The refunds service for the shop. Orders are captured by the payments
service and copied here; this service lets support issue full and partial
refunds against a captured order and publishes a `refund.created` event
for the ledger.

Amounts on the API are integers in paise (1 rupee = 100 paise). The test
case table and the backlog write amounts in rupees.

Storage is in memory for now (internal/refunds/store.go); the Postgres
store lands with PAY-230.

    make check    # go vet and go test
    make run      # listens on :8080

Tests live beside the code (internal/refunds/*_test.go). Each automated
case in docs/testing/test-cases.md has one test whose name carries its
TC id, for example TestTC0101_FullRefundOfCapturedOrder.
