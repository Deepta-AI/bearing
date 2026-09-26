# 2. Cache carts in Redis

Date: 2026-03-02

## Status

Accepted

## Context

Cart reads were the busiest query on the api and carts are short lived.

## Decision

We will keep carts in a managed Redis with a 7 day TTL and read them from
Redis before Postgres.

## Consequences

A managed Redis per environment. Carts can be lost on a Redis failover.
