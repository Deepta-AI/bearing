# 0004. LLM provider

Status: Accepted (2026-06-10)

## Context
Employee data is personal data under the DPDP Act and UK GDPR. Legal has
approved the Anthropic API with zero data retention.

## Decision
We will use the Anthropic API for internal tools that send employee
content to a model. Training or hosting our own model needs a new ADR
and a security review.

## Consequences
No self-hosted models without a further decision.
