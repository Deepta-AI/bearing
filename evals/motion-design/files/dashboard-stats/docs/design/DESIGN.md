# Tally design notes

## Type

Inter at the sizes in dashboard.css. Figures on the dashboard use tabular
numerals so columns and changing values do not shift sideways.

## Colour

From tokens.css only; no literal colours in component styles.

## Motion

Approach: intentional. Motion explains a change; it never decorates.
Durations and easings come from the tokens in src/styles/tokens.css,
never literals. Every animation has a reduced-motion path that keeps the
end state. The figures are the thing people read, so nothing moves while
they are being read.
