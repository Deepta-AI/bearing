# Design review checklist

Eleven categories. Each starts at 10. A high finding deducts 3, a medium 1,
a polish note 0 (it is listed, not deducted). Floor 0. A category with
nothing to judge is `n/a: reason` and leaves the mean. Every deduction
has an evidence line: `file:line` or a screenshot name. Grep hints are
for source review; screenshots decide when both exist.

Weights: hierarchy 10, typography 15, spacing 10, colour 10, states 10,
responsive 10, copy 5, accessibility 10, motion 5, consistency 10, slop 5.
The slop category is also reported on its own; any hit caps it at 3.

The autopilot design_review gate reads the report: an overall of 8.0 and
no scored category below 7, with the evidence line showing every
screenshot present. The table rows keep the shape
`| <category> | <score or n/a: reason> | <weight>% | <evidence> |`.

## 1. Hierarchy (10%)

- The first three things the eye lands on are the page's job (from the
  flows or the title). A mismatch is high.
- One primary action per view. Two equal buttons is medium.
- Squint test: hierarchy survives blur. Everything the same weight is high.
- White space is grouping, not leftover. Related closer, sections apart.
- Trunk test: product, screen, sections, way back are all visible.
- Grep: `text-align: center` on more than one block-level rule is medium.

## 2. Typography (15%)

- Three or four sizes on one ratio; count the distinct `font-size` values.
  Five or more is medium; no ratio is medium.
- Two weights; a third is polish, four is medium.
- Measure 45 to 75 characters; body over 90 is high, under 40 medium.
- `text-wrap: balance` on headings; absent is polish.
- `font-variant-numeric: tabular-nums` where figures align; absent on a
  column of numbers is medium.
- Every face the CSS names is loaded (`@font-face` or a font link); a
  face that never loads is high: every screen shows the fallback.
- Display face is not Inter, Space Grotesk, Roboto, Arial or a system
  stack: hit is high (also a slop hit).
- One UI face and one mono across every screen; a second face carrying
  body text is high (two type systems read as two products).
- Body 16 px or more; smaller is high. Captions 12 px or more.
- Curly quotes, real ellipsis; straight or three dots is polish, except
  in copy the flows give, which stays character for character.
- Grep: `font-family`, `font-size`, `font-weight`, `text-wrap`, `tabular`.

## 3. Colour (10%)

- Contrast AA in light and in both dark paths: body 4.5:1, large (24 px,
  or 18.66 px bold) 3:1, field edges and focus rings 3:1 against their
  surround. Computed by `scripts/pairs.py`, per surface; a failure is high
  per theme. A raw colour in a page that fails in dark is high.
- A token overridden in one dark block and not the other is high.
- The accent has one job and the page says which. Accent on decoration
  is medium.
- 60/30/10 holds: count surfaces. A page that is mostly accent is high.
- Colours are stated in oklch or hex with a reason in the token comment;
  bare values are polish.
- Dark: surfaces step up for elevation, text off-white, accent
  desaturated. Pure black or pure white text is medium. No dark theme is
  high.
- Semantic colours carry a word; colour-only status is high.
- Grep: `:root`, `prefers-color-scheme`, `data-theme`, `#000`, `#fff`.

## 4. Spacing rhythm (10%)

- One scale. List every padding, margin and gap value; anything off the
  scale is medium, three or more is high.
- Radius and shadow hierarchy: one radius on every block is medium; one
  shadow on every block is medium (also slop).
- Max content width set; full-bleed body text is high.
- Alignment holds to a grid; a floating element is medium.
- Grep: `padding`, `margin`, `gap`, `border-radius`, `box-shadow`.

## 5. Interaction states (10%)

- Hover on every control; missing is medium.
- `:focus-visible` ring on every control, 3:1 against the surface it is
  drawn on (`pairs.py` measures it); `outline: none` without a
  replacement is high.
- Active, disabled (`opacity` plus `cursor: not-allowed`), loading
  (skeleton matches layout), empty (invitation plus action), error (what
  happened, what to do). Each missing state that the flows list is high.
- Destructive actions confirm or offer undo; missing is high.
- Grep: `:hover`, `:focus-visible`, `outline`, `:disabled`, `skeleton`.

## 6. Responsive (10%)

- No horizontal scroll at 375, 768, 1440; scroll is high.
- No half-width desktop column beside dead space at 1440; hit is high.
- The 375 layout is designed, not stacked desktop; stacked is medium.
- Navigation collapses to a sheet or drawer below 768; a sidebar that
  squeezes the content is high. Tables become cards or scroll in their
  own container; a table that overflows the page is high.
- Touch targets 44 px at 375, computed (a fixed `height` wins over
  padding); smaller is medium per control class.
- Viewport meta present, no `user-scalable=no`; hit is high.
- Grep: `@media`, `min-width`, `max-width`, `overflow-x`, `user-scalable`.

## 7. Motion (5%)

- Transform and opacity only; `width`, `height`, `top`, `left` animated
  is medium.
- Durations 150 to 700 ms and from tokens; `transition: all` is medium.
- One orchestrated moment; scattered effects are medium; none where the
  brief named one is polish.
- `prefers-reduced-motion` ends every animation in its end state; absent
  is high.
- Grep: `transition`, `animation`, `@keyframes`, `prefers-reduced-motion`.

## 8. Content and microcopy (5%)

- Buttons start with a verb and name the object; Submit, Continue, OK,
  Learn more are medium each.
- Errors say what happened and what to do; vague or apologetic is high.
- Empty states invite; "No items" alone is medium.
- Copy matches the flows word for word where the flows give it; a
  divergent label or message is medium, a state shown on the wrong page
  (an error on the default screen) is high.
- Sample data agrees with itself (status and dates, totals and lines);
  a contradiction the reader will notice is high.
- No lorem ipsum, no "Welcome to", no happy talk; hit is high.
- Instructions longer than one sentence are medium and name the control
  they compensate for.
- Grep: `lorem`, `Welcome`, `Submit`, `Continue`, `Oops`, `sorry`.

## 9. Accessibility (10%)

- Every input has a visible label; placeholder-only is high.
- Landmarks: `main`, `nav`, `header` present; missing `main` is medium.
- Heading order has no skipped level; skip is medium.
- Images have alt text that says what they show; missing is medium.
- Keyboard path covers every control in reading order (from `snapshot -i`
  or the DOM order); a control unreachable is high.
- `color-scheme` set on `html` when dark exists; absent is polish.
- Grep: `<label`, `aria-`, `role=`, `alt=`, `<main`, `tabindex`.

## 10. Consistency across screens (10%)

Judged over every screen in the review together, not page by page.

- One shell: the same navigation, header and page-title pattern on every
  screen; a screen with its own layout is high.
- The same thing looks the same everywhere: one table style, one status
  badge per meaning, one empty state, one error pattern, one primary
  button style; each divergence is medium.
- Components from the library, not hand-built look-alikes: a table or
  button styled locally beside the library's is high (design-lint counts
  them as raw elements).
- One spacing rhythm and one density; a screen visibly tighter or looser
  than the rest is medium.
- Grep: raw `<table`, `<button`, `<input` outside `components/ui`;
  `font-family`; arbitrary `text-[`, `p-[`, `gap-[` values.

## 11. AI slop detector (5%, any hit caps at 3)

Hard rules: cream plus serif plus terracotta; near-black plus acid
green; purple-to-blue gradient hero; Inter or Space Grotesk as display;
emoji as markers; everything centred; one radius and one shadow
everywhere; half-width desktop with dead space; undeclared colours;
lorem ipsum; one theme only; motion without the reduced-motion guard;
focus not visible.

Patterns: three-column icon-in-circle feature grid; icons in coloured
circles; blobs, floating circles, wavy dividers; coloured left border on
cards; cards as layout; cookie-cutter section rhythm; big number plus
small label plus gradient hero; numbered markers on a non-sequence;
generic hero copy; system-ui as the primary face.

Grep: `linear-gradient(`, `border-left:`, `Inter`, `Space Grotesk`,
`system-ui`, `-apple-system`, `text-align: center`, `border-radius`.

## Report shape

```
### First impression: <page>
Communicates: ... / I notice: ... / Eye lands on: 1 ... 2 ... 3 ... / One word: ...
### Findings
| # | Category | Impact | Where | Change X to Y because Z |
```
