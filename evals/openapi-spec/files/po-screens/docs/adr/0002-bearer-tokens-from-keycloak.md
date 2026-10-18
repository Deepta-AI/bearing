# 2. Bearer tokens from Keycloak

Date: 2026-06-10

## Status

Accepted

## Context

The web and mobile clients already sign users in through the company
Keycloak realm `procure`. Each user belongs to exactly one buyer company.

## Decision

We will authenticate every API call with a Keycloak access token (JWT)
in `Authorization: Bearer <token>`. The token carries `company_id` and
realm roles. Two roles matter to the API: `buyer` (create, submit and
cancel purchase orders) and `approver` (approve them). A user may hold
both roles.

## Consequences

The API never sees passwords. Company scoping comes from the token,
never from a request parameter.
