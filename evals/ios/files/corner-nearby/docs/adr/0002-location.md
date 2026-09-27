# 2. Use of the customer's location

Status: Accepted (2026-08-18)

## Context

Store search by location is planned. The privacy review for 2.4 agreed the
limits below with the product owner.

## Decision

- When-in-use authorization only. The app never asks for Always and adds
  no background location mode.
- Ask at the moment of need (when the customer opens a screen that uses
  location), never at launch.
- Coordinates are rounded to 2 decimal places (about 1.1 km) before they
  leave the device. The precise fix is never sent.
- Coordinates are never persisted and never logged, in any build.
- If the customer declines, the screen explains why location helps and
  offers a way to open Settings; the rest of the app works as before.

## Consequences

The App Store privacy details and `PrivacyInfo.xcprivacy` must declare
location as collected data (coarse, linked to app functionality, not used
for tracking) once a feature sends it.
