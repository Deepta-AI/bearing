# inventory-ops

Stock records for the three warehouses (BLR-1, PNQ-1, DEL-2): SKUs, stock
per warehouse, and every stock movement. The ops team edits stock after a
recount and cleans up SKUs that were created by mistake.

Python 3.12+, standard library only: this repository may not take
third-party packages (platform security review, see the note in
`mcplite/README.md`).

- `inventory/service.py`: `InventoryService`, the operations
- `inventory/store.py`: the in-process store; `seeded()` gives synthetic data
  for local runs and tests (production binds the Postgres store from the
  platform image through `INVENTORY_STORE=postgres` and `INVENTORY_DB_URL`)
- `mcplite/`: the platform team's minimal MCP runtime over stdio (server and
  a test client), vendored because the `mcp` package is not allowed here
- `docs/ops/inventory-rules.md`: the rules ops work by

    make check
