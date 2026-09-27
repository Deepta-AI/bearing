# 1. Server data lives in TanStack Query

Status: Accepted (2025-11-04)

## Context

The first version kept API results in a Zustand store and in component
state, and screens showed stale addresses after an edit on another device.

## Decision

Every API read is a `useQuery` (or `useInfiniteQuery`) and every write a
`useMutation`. Query results are read where they are used and never copied
into Zustand, component state or a ref. Zustand holds client state only:
the session status and UI preferences.

## Consequences

Refetch on focus and invalidation keep screens fresh. `app/(app)/addresses.tsx`
predates this decision and still copies its query into state; it is on
the list to fix.
