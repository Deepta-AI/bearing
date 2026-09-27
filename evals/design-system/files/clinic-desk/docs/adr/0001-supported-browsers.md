# ADR-0001: Supported browsers

Status: Accepted

## Context

The clinic group's front desks run on iPads they bought in 2019 and 2020.
Their IT team confirmed in June that a third of them cannot be updated past
iPadOS 15.1, and there is no budget to replace them this year.

## Decision

We support Safari 15.0 and later on iPad, plus the current and previous
versions of Chrome and Edge on desktop. Every screen must render correctly
on Safari 15.0: no feature that Safari 15.0 lacks may be required for
colour, layout or text to show.

## Consequences

New CSS features are used only with a fallback that Safari 15.0 renders.
This is revisited when the clinic group replaces the older iPads.
