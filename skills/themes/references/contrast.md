# Contrast: the formula and the pairs

`theme-lint.py` implements this page. Read it to understand a failure,
or to add a pair when a new role appears in `tokens.json`.

## The formula (WCAG 2.x)

1. Take the colour in sRGB, each channel 0 to 1. From oklch, convert
   through OKLab and LMS to linear sRGB (the matrices are in the
   script and in `design-system`'s stack bindings); from hex,
   decode gamma: `c / 12.92` when `c <= 0.04045`, else
   `((c + 0.055) / 1.055) ^ 2.4`.
2. Relative luminance `L = 0.2126 R + 0.7152 G + 0.0722 B` on the
   linear values.
3. Contrast `(L1 + 0.05) / (L2 + 0.05)` with `L1` the lighter.

Thresholds: AA text 4.5:1; AA large text (24px, or 19px bold) 3:1;
AAA text 7:1; non-text UI (edges, icons, focus, indicators) 3:1.
Disabled controls are exempt and only reported.

The lint works on the oklch value, so the ratio is the one a modern
browser renders. `--strict-hex` also fails when the hex fallback
drifts from the oklch by a rounding step, which matters only where the
fallback will actually paint.

Alpha is ignored for the ratio; a translucent role (`overlay`) is not
in any pair. Text over a translucent surface must be checked against
the composite colour by hand, or the surface made opaque.

## The pairs

Body pairs, 4.5:1 and AAA 7:1 where the base mode reaches it:

| Foreground | Background |
| --- | --- |
| text | bg, bg-subtle, surface, surface-raised |

Text pairs, 4.5:1:

| Foreground | Background |
| --- | --- |
| text-muted | bg, surface, surface-raised |
| link | bg, surface |
| on-accent | accent, accent-hover, accent-active |
| on-success, on-warning, on-danger, on-info | success, warning, danger, info |
| text | accent-subtle, success-subtle, warning-subtle, danger-subtle, info-subtle, selection |

UI pairs, 3:1:

| Foreground | Background |
| --- | --- |
| accent | bg, surface |
| border-strong | bg, surface |
| focus | bg, surface, surface-raised |
| danger, success | surface |

Reported only: text-disabled on surface and on bg; focus on accent (the
ring sits on an offset gap that shows the surface).

A high-contrast theme raises every body and text pair to 7:1 and every
UI pair to 4.5:1.

## Why these and not every combination

Every pair above is one a component in `docs/design/components.md`
actually paints: a label on a surface, a button label on its fill,
text inside a tinted callout, a ring around a control. `border` (the
hairline) is not checked because a divider is not a UI boundary a user
must perceive; `border-strong` (input edges) is. A new component that
paints a new combination adds a row here and a tuple in `PAIRS`.

## Fixing a failure

- Text on a surface too low: move the text role a step darker (light)
  or lighter (dark) on the same scale; never fix it by tinting the
  surface towards grey, which flattens the whole theme.
- `on-accent` on `accent` too low: the accent is mid-lightness (L 55
  to 70 in oklch); pick `on-accent` from the neutral end that gives
  4.5 and, if neither does, move the accent one step.
- Warning is the usual failure: yellow at usable chroma sits at L 80
  and cannot carry white text. Use `neutral.1000` as `on-warning`, or
  a warning at L 56 with low chroma (the fixture uses ochre).
- Subtle tints (`*-subtle`) must stay near the surface (L 95 plus in
  light, L 20 minus in dark) so `text` still passes on them.
- Focus on accent is reported, not failed: the ring is drawn with an
  offset and the gap shows the surface. Where a ring must sit flush
  (a filled control inside a toolbar) use a two-tone ring, `focus`
  outside `surface`.
