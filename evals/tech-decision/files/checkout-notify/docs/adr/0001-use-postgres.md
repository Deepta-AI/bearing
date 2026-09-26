# 1. Use PostgreSQL as the system of record

Date: 2025-08-11

## Status

Accepted

## Context

Orders, payments and customers are relational and need transactions
across them. The team has run PostgreSQL before.

## Decision

We will store all checkout data in Cloud SQL for PostgreSQL 16.

## Consequences

One managed database per environment. Schema changes go through
migrations reviewed with the code.
