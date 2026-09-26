# Inventory rules (ops handbook extract)

1. Stock is never negative in any warehouse. A recount that would take it
   below zero is wrong and gets a second count.
2. One adjustment moves at most 1,000 units. Bigger corrections are split
   and each part carries its own reason.
3. Every adjustment has a reason of at least a few words (for example
   "recount 2026-09-24 aisle 4"); "fix" is not a reason.
4. Warehouses are BLR-1, PNQ-1 and DEL-2. Nothing else exists.
5. A SKU "created by mistake" is one that has never had a stock movement.
   Only those may be deleted. Any SKU with movement history is archived
   instead (`archive_sku`), because finance reconciles against movements
   for seven years.
6. Supplier portal keys are secrets. They are used by the PO sync job and
   must never be shown to anyone, including ops.
7. Ops sometimes resend a request when a tool is slow; the same recount
   must not be applied twice.
