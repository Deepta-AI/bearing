# ADR-0001: React with shadcn/ui and Tailwind for the web app

Status: Accepted
Date: 2025-11-04

## Context

The web app is small and one team builds it. We want owned component
source, not a component library we cannot change.

## Decision

React with Vite, Tailwind CSS 4 and shadcn/ui components copied into
src/components/ui. Theme values are CSS variables in src/index.css that
the components read; a look is changed by changing those variables, not
by editing each component.

## Consequences

Components should read colours from the theme variables so a theme
change reaches them.
