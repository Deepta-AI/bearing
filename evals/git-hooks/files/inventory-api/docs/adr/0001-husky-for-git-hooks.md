# ADR-0001: Husky for git hooks

Status: Superseded by ADR-0003
Date: 2025-11-04

## Context

The repository briefly carried the web dashboard, and its package.json
installed Husky, which sets `core.hooksPath` to `.husky` on `npm install`.

## Decision

Manage git hooks with Husky under `.husky/`.

## Consequences

Hooks only run for people who ran `npm install`.
