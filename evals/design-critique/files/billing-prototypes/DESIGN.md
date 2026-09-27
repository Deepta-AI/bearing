# Tallybook design system

## Type

- UI face: IBM Plex Sans, on every screen, for everything that is not a figure.
- Figures (amounts, invoice numbers, dates in tables): IBM Plex Mono.
- Sizes: 13, 16, 20, 28 px (a 1.25 ratio, rounded). Body text is 16 px.
- Weights: 400 and 600 only.

## Colour

All colours come from `docs/design/tokens.css`; a page never states a raw
colour. Light and dark are both first class: dark is switched with
`data-theme="dark"` on `<html>` and follows the system setting otherwise.

- Accent (amber) marks the one primary action on a screen and nothing else.
- Every text colour meets WCAG AA on the surface it sits on, in both themes
  (4.5:1 for body text, 3:1 for text 24 px and larger).
- Status is a word first (Paid, Overdue, Draft) and a colour second.

## Spacing

4 px base: 4, 8, 12, 16, 24, 32, 48. Radius 6 on controls, 10 on panels.

## Layout

Content is left-aligned. Screens are designed at 375, 768 and 1440 wide;
tables that do not fit at 375 scroll inside their own container, never the page.
