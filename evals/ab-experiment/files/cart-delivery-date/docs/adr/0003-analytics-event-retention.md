# 3. Raw analytics events are kept for 42 days

Status: Accepted
Date: 2026-03-18

## Context

Raw events carry device ids and, for signed-in visitors, user ids. The
privacy review limited how long identifiable raw events may be stored.

## Decision

The warehouse deletes raw events 42 days after they were received. The only
long-lived tables are the weekly platform funnel (`funnel-weekly.csv` is an
export of it) and daily revenue totals; neither carries a user or device id
or any experiment variant.

## Consequences

Any analysis that joins events per user or per device must be run on events
younger than 42 days. Work that needs a longer window must keep its own
aggregate that holds no identifier, and that aggregate needs a privacy
review before it is created.
