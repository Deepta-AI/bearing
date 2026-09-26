# ADR 0002: Expand, migrate, contract

Status: Accepted (January 2026)

## Context

The deploy script runs the migrations first and restarts the app a few
minutes later, after the new build is copied. Rollouts are sometimes held
for a day. During that window the previous release writes to the new schema.

## Decision

A schema change that replaces a column ships in steps: add the new column
and fill it (expand), switch the code to it (migrate), and drop the old
column one release after nothing reads it (contract). No release renames or
drops a column that the previous release still reads or writes. Every
migration has a Down that is tested by `tests/test_migrations.py`.
