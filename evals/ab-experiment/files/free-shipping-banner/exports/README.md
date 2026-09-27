# Exports

Warehouse exports for experiment read-outs. Each file is a one-off query
result; the query text is kept in the analytics team's warehouse repo.

## free-shipping-banner-results.csv

- Run: Friday 2026-09-25 at 18:00 IST.
- Rows: one per variant and platform.
- `exposed`: distinct devices with an `experiment_exposed` event for
  `free-shipping-banner` from 2026-09-01 00:00 to the export time.
- `converted`: of those devices, the ones with at least one
  `order_placed` after their first exposure, up to the export time.

## Note from analytics, 2026-09-25

The web split looks off because crawlers render product pages and land in
control. 2,050 of the exposed web devices are on the known-bot list (1,980
in control, 70 in treatment, none with an order). Without them web is
18,320 control against 18,130 treatment, which is back to 50/50, so the
bot-filtered numbers should be fine to read.
