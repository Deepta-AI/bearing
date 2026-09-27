# ADR-0001: The console is React with shadcn/ui

Status: Accepted, 2 Feb 2026

## Decision

Payline Ops is a React single-page app built with Vite, Tailwind and
shadcn/ui. Screens compose the components in `src/components/ui`; a new
pattern extends a component with a variant instead of hand-styling markup.

## Consequences

One component set and one set of tokens for every screen.
