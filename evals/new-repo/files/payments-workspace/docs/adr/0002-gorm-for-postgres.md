# ADR-0002: GORM for Postgres access

Status: Superseded by ADR-0006
Date: 2024-11-04

## Context

The first two services needed Postgres access quickly.

## Decision

Go services use GORM with its auto-migration for Postgres.

## Consequences

Fast to start; the schema lives in struct tags.
