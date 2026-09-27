# Design doctrine

The rules a variant is built by and a review scores against. Hard rules
fail a page. The rest are how to make a choice that is a choice. The
project's own rules (accepted ADRs, the CSP, the hardware in the README)
come first: where they are stricter or fix a number, they replace the
number here.

## Hard rules

1. Not cream background plus high-contrast serif plus terracotta accent.
2. Not near-black plus one acid green or vermilion accent.
3. Not a purple-to-blue gradient hero, and no purple, violet or indigo
   gradients as background.
4. Inter, Space Grotesk, Roboto, Arial and system stacks are never the
   display face. They may serve as body only when the brief names them.
5. No emoji as section markers, bullets or decoration.
6. Not everything centred. Headings, body and cards default to a left
   edge; centring is a decision for one element.
7. Not one radius and one shadow on every block. Radius and shadow form
   a hierarchy: outer larger than inner, shadow only where a surface is
   raised.
8. No half-width desktop layout with dead space beside a column. At 1440
   the content either fills a measured column set or pairs with
   something.
9. Colours are derived deliberately and stated in oklch or hex with the
   reason ("accent L 0.62 for AA on both surfaces").
10. Real content. Never lorem ipsum, never "Welcome to", never "Unlock
    the power of".
11. Light and dark both designed, unless the product has one theme:
    dark surfaces step up in lightness for elevation, text is off-white,
    the accent is desaturated 10 to 20%.
12. `prefers-reduced-motion` turns every animation into a state change.
13. Keyboard focus is visible on every control: `:focus-visible` with a
    2 px ring offset from the edge, never `outline: none` without one.
14. Body text 16 px or larger and 4.5:1 contrast on both surfaces;
    touch targets 44 px on a phone; field edges 3:1. The project's floor
    wins when higher (a kiosk's 7:1 and 64 px).

## Anti-slop list (a hit is a finding)

- The three-column feature grid: icon in a coloured circle, bold title,
  two-line blurb, repeated three times.
- Icons in coloured circles as decoration.
- Uniform large border radius everywhere.
- Decorative blobs, floating circles, wavy dividers.
- Coloured left border on cards.
- Cards as layout: an app screen made of stacked cards instead of a grid.
- Cookie-cutter rhythm: hero, three features, testimonials, pricing, CTA,
  every section the same height.
- A big number with a small label and a gradient accent as the hero.
- Numbered markers (01, 02, 03) on content that is not a sequence.
- Generic verbs on buttons: Submit, Continue, Learn more, Get started.
- Placeholder as the only label on an input.
- Straight quotes and three dots where curly quotes and an ellipsis belong.

## The generic-default pass

Write the brief. Then write the default answer any similar brief would
get. Every line of the plan that matches the default is revised, and the
change is written down with its reason. Build only after the plan is
confirmed different. Then the mirror: before showing, remove one thing.

## Ground it in the subject

Name the subject, its audience, and the page's single job. Distinctive
choices come from the subject's world: its materials (paper, steel,
glass, cloth), its instruments (a ledger, a gauge, a scoreboard, a
chart), its vernacular (how its people actually write). The hero is a
thesis: open with the most characteristic thing in that world. The world
feeds the look; the users decide it. A direction that cannot say which
user it serves first, in which conditions (desk, sun, arm's length), is
decoration.

## Directions list

Pick one row per variant. Faces are open-licence families, most on
Google Fonts and Fontsource; load them the way the project allows (a
Fontsource package or self-hosted file where third-party hosts are
forbidden or unreachable). Rows are starting points; the brief, not the
row, decides.

| Direction | Display face (examples) | Body | Temperature | Rhythm | Motion moment |
| --- | --- | --- | --- | --- | --- |
| Editorial | Fraunces, Newsreader, Instrument Serif | Source Serif 4, Literata | warm paper | wide measure, drop caps, pull quote | headline settles letter by letter |
| Swiss grid | Archivo, Familjen Grotesk, Schibsted Grotesk | same family, one weight apart | neutral cool | strict 12 columns, hairlines, flush left | grid lines draw in |
| Instrument panel | IBM Plex Sans Condensed, Barlow Condensed | IBM Plex Sans | cool graphite | dense rows, tabular numbers, status rail | readouts count up once |
| Workshop | Bricolage Grotesque, Syne | Public Sans | warm ochre and steel | big margins, one object per band | the object rotates into place |
| Field guide | Libre Caslon, Cormorant Garamond | Atkinson Hyperlegible | natural greens and bone | two-column plates with captions | plates fade in on scroll |
| Ledger | Spectral, DM Serif Text | Work Sans | ink on cream-grey, one red | ruled rows, right-aligned figures | the total line underlines itself |
| Terminal | JetBrains Mono, Fragment Mono | same mono | near-black is banned; use deep navy or forest | monospace grid, prompt lines | cursor types the headline |
| Blueprint | Unbounded, Big Shoulders Display | Figtree | cyan on slate | annotated drawing, leader lines | leader lines extend to labels |
| Signage | Anton, League Gothic, Oswald | Sora | high-contrast single hue | poster bands, huge type, small body | the band slides up once |
| Civic form | Lora, Merriweather | Public Sans | muted teal and grey | form sections, numbered because they are steps | the completed step ticks |
| Stage | Playfair Display, Bodoni Moda | Karla | deep plum or wine, gold hairline | full-bleed image, small caption | curtain of light sweeps once |
| Scoreboard | Chakra Petch, Rajdhani | Manrope | one team colour on charcoal | scoreline rail, big tabular figures | the leading score flips |

## Distinctness axes and the swapped-headline test

Two variants are different when all three differ: display family
(serif, grotesque, condensed, mono, display), palette temperature (warm,
cool, neutral, one-hue), layout rhythm (measure, column count, band
height, alignment). Then: move the headline text from one page to the
other. If nothing looks wrong, they are siblings; regenerate the weaker
one from another row.

## Typography

- Display and body from different classes, or one family two weights
  apart when the direction says so. Two families, at most three with a
  utility mono for data.
- Three or four sizes on a ratio (1.25 or 1.333). Two weights.
- Measure 45 to 75 characters; 66 is the target for body.
- `text-wrap: balance` on headings, `tabular-nums` on figures, curly
  quotes, a real ellipsis, no letterspacing on lowercase.
- Line height 1.5 body, 1.1 to 1.25 headings.

## Colour

- 60% surface, 30% secondary surface, 10% accent, and the accent has one
  job (the primary action, or the current position). Name that job.
- Derive in oklch: keep hue, move L for surfaces, move C for emphasis.
- Semantic colours are consistent and never colour-only; error carries
  a word.

## Spacing and layout

- One scale (4, 8, 12, 16, 24, 32, 48, 64) and nothing off it.
- Related things closer, sections further; the gap encodes the grouping.
- Max content width set; body text never full-bleed.
- 375, 768 and 1440 are three layouts, not one layout stacked.

## The motion moment

One orchestrated moment per page: an entrance sequence, a scroll reveal
or a hover system, never all three. Transform and opacity only, 200 to
700 ms, ease-out in, ease-in out, properties listed (no `transition:
all`), within the project's limit when it sets one. Under reduced
motion the end state renders immediately.

## Copy

Write from the user's side of the screen. Buttons say what happens
("Save changes"), and keep the same name through the flow. Errors say
what happened and what to do; they never apologise or go vague. Empty
states invite the first action. Sentence case, plain verbs, no filler.
