# ADR-0005: Accessibility floor for the kiosk

Status: Accepted
Date: 2025-09-12

## Context

The kiosk stands in a lit waiting room at about 60 cm from the patient.
In the first pilot, glare from ceiling lights washed out grey text, and
patients with tremor missed the 48 px keys.

## Decision

On every kiosk screen:

- Text at body size (below 32 px, or below 24 px bold) has a contrast of
  at least 7:1 against its background. Larger text needs at least 4.5:1.
- No text is smaller than 24 px.
- Every touch target is at least 64 x 64 px with 16 px between targets.
- One light theme only; no dark mode.
- No animation longer than 300 ms, and none that repeats.

## Consequences

Colour tokens are checked against these ratios before they are used for
text.
