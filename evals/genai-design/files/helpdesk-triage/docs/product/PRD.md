# PRD: Smart ticket routing

Owner: Product, Support Experience
Status: Draft for engineering review

## Background

Every inbound support email is routed to a queue by keyword rules. The
rules were written in 2023 and nobody trusts them any more. Support leads
spend part of every morning moving tickets between queues.

## Requirements

- REQ-001: Route every inbound support email to one of six queues:
  billing, invoicing, integrations, account_access, bug_report, general.
- REQ-002: Build an AI agent that reads each email, looks up the customer
  in the CRM and decides the queue, the same way a support lead would.
- REQ-003: Enterprise accounts (CRM tier = enterprise) go to the priority
  lane of their queue.
- REQ-004: A ticket is routed within 60 seconds of the email arriving.
- REQ-005: Phase 2, not in this release: the agent drafts a first reply.
- REQ-006: Model spend for routing must stay under USD 500 a month.
  Finance has set this as a hard cap for this feature.

## Volume

About 38,000 inbound emails a day on weekdays, with Monday mornings at
roughly three times the hourly average. Weekend volume is small.

## Success

Route tickets more accurately than today so leads stop moving tickets
by hand.

## Out of scope

Reply drafting, sentiment, language detection.
