# 0004. Disable system font scaling

Status: Accepted (2025-11-03)

## Context

At the largest iOS and Android text sizes the balance on the Home card was
cut off, and support received screenshots of a clipped balance.

## Decision

Set allowFontScaling to false on Text and TextInput app-wide (app/_layout.tsx).
Revisit when the Home card is redesigned.

## Consequences

Text no longer follows the user's system text size anywhere in the app.
