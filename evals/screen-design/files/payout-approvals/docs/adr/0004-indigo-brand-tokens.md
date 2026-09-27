# ADR-0004: Indigo brand, tokens in src/index.css are the source of truth

Status: Accepted, 12 Jun 2026

## Context

The group rebrand in May 2026 replaced the teal primary with indigo. Two
places described colour: `docs/design/DESIGN.md` and the CSS variables in
`src/index.css`, and they had already drifted once.

## Decision

- The primary colour is indigo, as the `--primary` token in `src/index.css`
  (light and dark) defines it.
- `src/index.css` is the only source of colour, radius and type. Screens and
  mockups use the role tokens (`primary`, `muted-foreground`, `destructive`,
  `success`, `warning`), never a literal colour value.
- `docs/design/DESIGN.md` is historical and is not updated.

## Consequences

Any design that uses the old teal is out of date.
