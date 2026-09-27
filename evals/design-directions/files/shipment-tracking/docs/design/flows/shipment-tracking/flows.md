# Shipment tracking: flows

Feature: one page per shipment for dispatchers (desktop, all day) and for
drivers or warehouse leads who open the shared tracking link on a phone.

## Screens

| Id | Screen | States |
| --- | --- | --- |
| S-01 | Tracking | in transit (happy path), delayed, carrier not reachable, no movement yet |
| S-02 | Not found | reference unknown |

Sample data for every state is in src/data/shipments.ts (shp_1042 in
transit, shp_1043 delayed, shp_1044 carrier not reachable and no
movement).

## Copy

- Primary action: "Notify consignee"
- Secondary action: "Copy tracking link"
- Delayed: "Now expected <eta>, after the promised <promised>. Let the
  consignee know before they plan unloading."
- Carrier not reachable: "<carrier> is not sending updates. The last
  position may be out of date; call the carrier to confirm."
- No movement: "No movement yet. Updates appear here once the truck is
  loaded."
- Not found: "We could not find that shipment. Check the reference and
  try again."

## Notes

Status is never shown by colour alone; the badge always carries its word.
