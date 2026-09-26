# 0002. LLM provider for product features

Status: Accepted (2026-06-30)

## Context
Customer email content may only be sent to vendors on the approved
processor list. Legal approved Anthropic's API (zero data retention
agreement signed) in June.

## Decision
We will use the Anthropic API directly for any product feature that
sends customer content to a language model. Other providers need a new
ADR and a legal review.

## Consequences
Model choice is limited to Anthropic models until another vendor is
reviewed.
