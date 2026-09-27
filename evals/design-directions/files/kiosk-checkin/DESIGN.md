# Queuewell design system

Last reviewed: October 2025

## Faces

- Display: Fraunces, 600, for screen titles and the patient's name.
- Body and controls: Atkinson Hyperlegible, 400 and 700.

## Colour

| Token | Value | Use |
| --- | --- | --- |
| --surface | #FFFFFF | page |
| --surface-2 | #F1F5F4 | panels, keypad |
| --ink | #10231F | text |
| --ink-muted | #6B7280 | hints, secondary text |
| --accent | #0F766E | primary action, current step |
| --accent-ink | #FFFFFF | text on accent |
| --danger | #B42318 | errors, always with a word |
| --line | #D0D5DD | rules and input borders |

## Shape

Radius 12 px on panels, 8 px on keys and buttons. One shadow, on the
keypad panel only.

The tokens live in static/css/tokens.css.
