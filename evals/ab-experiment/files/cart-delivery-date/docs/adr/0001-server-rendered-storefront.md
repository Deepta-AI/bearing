# 1. Server-rendered storefront

Status: Accepted
Date: 2025-11-03

## Context

The storefront must work on slow mobile connections and be indexable.

## Decision

Render every page on the server in Node; no client-side framework.

## Consequences

Layout differences between mobile and desktop are decided per request from
the user agent.
