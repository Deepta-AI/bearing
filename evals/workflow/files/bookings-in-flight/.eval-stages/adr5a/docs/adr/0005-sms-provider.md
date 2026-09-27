# ADR-0005: SMS provider for booking reminders

- Status: Accepted
- Date: 2026-09-24

## Context

BK-104 sends a reminder SMS before each booking. We have quotes from two
providers; one supports DLT template registration out of the box.

## Options

1. Provider A: cheaper per message, DLT templates registered by us.
2. Provider B: DLT templates registered by the provider, 10% dearer.

## Decision

Provider B. The DLT registration it handles outweighs the higher price at our volume.
