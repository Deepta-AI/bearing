# Design System: <Product>

<!-- Template guidance: the written guide to this product's design system:
     the product it serves, the direction, and the reasoning behind each
     scale in docs/design/tokens.json. Designers and engineers read it
     before building a screen, and gstack's design skills read it through
     the root DESIGN.md symlink. The tokens are the source of truth: every
     value here is copied from tokens.json, and every angle bracket is
     filled. Delete each comment when you fill its section. -->

Tokens live in `docs/design/tokens.json` (v<version>); this guide
explains them. The component contract is `docs/design/components.md`.
Themes are under `docs/design/themes/`. `make design-lint` enforces the
scales. When this guide and the tokens disagree, the tokens win and this
guide is wrong.

## Product Context

<!-- What: what the product is, who uses it, its category and peers, the
     project type and the one thing a first-time user should remember.
     Good: specific users and a named peer set, not "modern users"; the
     memorable thing is a single concrete element, not a feeling.
     Example: "Who it's for: clinic front-desk staff booking 60 to 120
     appointments a day on a shared desktop." -->

- **What this is:** <one or two sentences>
- **Who it's for:** <the users>
- **Space/industry:** <category, peers>
- **Project type:** <web app / dashboard / marketing site / editorial / internal tool / mobile app>
- **Memorable thing:** <the one thing a first-time user should remember>

## Aesthetic Direction

<!-- What: the chosen direction with its reason, decoration level, mood,
     signature element, references and the defaults rejected.
     Good: the reason ties to the product context; the rejected defaults
     line stays unless the direction names one of them in its own words;
     references are real URLs or left out.
     Example: "Direction: ledger-precise because staff scan dense
     schedules all day and trust columns that line up." -->

- **Direction:** <name> because <one line>
- **Decoration level:** <minimal / intentional / expressive>
- **Mood:** <how the product should feel, one or two sentences>
- **Signature:** <the single element the product is remembered by>
- **Reference sites:** <URLs, if research was done>
- **Rejected defaults:** cream and terracotta, near-black and acid
  green, purple-blue gradients, uniform radius on every block, cards as
  layout.

## Typography

<!-- What: the display, body, UI, data and code faces, how they load,
     the size scale and the weights.
     Good: each face has a reason; never Inter, Space Grotesk, Roboto,
     Arial, Helvetica, Open Sans, Lato, Montserrat or Poppins as display
     or body; three to five sizes on one scale; two UI weights, a third
     only for display; sizes match the tokens.
     Example: "Body: Source Serif 4 because long appointment notes stay
     readable at 16px." -->

- **Display/Hero:** <face> because <one line>. Loaded from <source>.
- **Body:** <face> because <one line>.
- **UI/Labels:** <face or "same as body">
- **Data/Tables:** <face> with tabular figures.
- **Code:** <mono face>
- **Loading:** <self-hosted files under `public/fonts/` with `font-display: swap`, or the CDN>
- **Scale:** <size tokens with px, e.g. label 13, body 16, title 22, display 32, hero clamp(40px, 6vw, 72px)>
- **Weights:** <regular 400, emphasis 600; display 700 only>

## Color

<!-- What: the colour approach, the oklch derivation, the accent and its
     meaning, neutrals, semantic roles, the 60/30/10 split, dark mode and
     contrast.
     Good: every value is oklch with its computed hex fallback from
     tokens.json; dark mode is designed, never inverted; the contrast
     line quotes contrast.py, never judgement, with 0 pairs below
     minimum.
     Example: "Primary: accent.500 oklch(0.58 0.14 250) (#3f6fc4) for the
     one action per view and the current nav item." -->

- **Approach:** <restrained / balanced / expressive> because <one line>
- **Derivation:** accent hue <h> in oklch; neutrals carry chroma
  <0.004 to 0.016> of the same hue; every scale holds hue and varies
  lightness. Values are oklch with hex fallbacks in `tokens.json`.
- **Primary:** `accent.500` <oklch> (<hex>) for <what it means>
- **Neutrals:** `neutral.0` to `neutral.1000`
- **Semantic:** success `success.500`, warning `warning.500`, danger
  `danger.500`, info `info.500`, each with an `on-` role and a `-subtle`
  tint that keep 4.5:1.
- **60/30/10:** 60 percent `bg` and `surface`, 30 percent `text` and
  `border`, 10 percent accent. Accent is reserved for: <primary
  action, current navigation item, links, focus>.
- **Dark mode:** designed, not inverted. Surfaces lift with lightness
  (`neutral.1000`, `900`, `700`), accent one step lighter, chroma down
  10 to 20 percent, text `neutral.0`.
- **Contrast:** every text-on-surface pair at 4.5:1; body text on `bg`
  and `surface` at <7:1 where achieved>; UI edges and focus at 3:1.

## Spacing

<!-- What: the base unit, the density and the spacing scale.
     Good: 8px base with the single 4px half step; the density follows
     the product context; the scale names the tokens, not raw pixels
     alone.
     Example: "Density: compact, because a day view must show 40 slots
     without scrolling at 1440 wide." -->

- **Base unit:** 8px with one 4px half step
- **Density:** <compact / comfortable / spacious>
- **Scale:** 0, 4, 8, 16, 24, 32, 48, 64, 96 as `space.0` to `space.8`

## Layout

<!-- What: the layout approach, grid, maximum width, desktop rule, radius
     hierarchy and elevation rule.
     Good: radius is a hierarchy (control, container, overlay, full),
     never one value on everything; a shadow only on what can be pressed
     or floats; no half-width column beside empty space above md.
     Example: "Border radius: control 4px, container 8px, overlay 12px,
     full for avatars and switches." -->

- **Approach:** <grid-disciplined / creative-editorial / hybrid>
- **Grid:** <12 columns at lg, 8 at md, 4 at sm>
- **Max content width:** <1200px>
- **Desktop rule:** above `md` the width is used: paired columns or a
  grid. A half-width column beside empty space is a finding.
- **Border radius:** control <6px>, container <12px>, overlay <16px>,
  full. Never one radius on everything.
- **Elevation:** level 0 flat, 1 pressable at rest, 2 pressable hovered,
  3 overlay. A shadow means the element can be pressed or it floats
  above the page. Static blocks are flat.

## Motion

<!-- What: the motion approach, durations, easings, stagger and the rule
     for reduced motion.
     Good: durations 80, 150, 240, 400 and 700 ms as in the tokens; one
     orchestrated moment per page; transform and opacity only;
     prefers-reduced-motion sets every duration to zero.
     Example: "Easing: standard cubic-bezier(0.2, 0, 0, 1), enter
     cubic-bezier(0, 0, 0, 1), exit cubic-bezier(0.3, 0, 1, 1)." -->

- **Approach:** <minimal-functional / intentional / expressive>
- **Durations:** instant 80ms, fast 150ms, base 240ms, slow 400ms,
  deliberate 700ms
- **Easing:** standard <curve>, enter <curve>, exit <curve>, spring
  <stiffness, damping, mass>
- **Stagger:** <40ms>
- **Rule:** one orchestrated moment per page; everything else quiet.
  Transform and opacity only. `prefers-reduced-motion` sets every
  duration to zero and replaces movement with a fade or nothing.
- **Detail:** `docs/design/motion.md` when `motion-design` has written it.

## Focus and accessibility

<!-- What: the focus ring, target sizes, and the accessibility conditions
     that are part of done for every screen.
     Good: the ring is drawn with outline from the focus tokens and
     reaches 3:1 on every surface; targets 44pt on mobile; both modes,
     reduced motion and 200 percent zoom are stated.
     Example: "Focus ring: 2px focus role at 2px offset, 3.4:1 on
     surface-raised in dark (contrast.py)." -->

- Focus ring: `focus.width`px `focus` role at `focus.offset`px, drawn
  with `outline`, visible on every surface at 3:1.
- Touch targets 44pt on mobile; 40px controls on desktop.
- Both colour modes, reduced motion and 200 percent zoom are part of
  the definition of done for any screen.

## Themes

<!-- What: the base modes, where extra themes live and what a tenant may
     change.
     Good: extra themes override roles only; tenants never change spacing,
     motion or focus; the allowed faces are listed by name.
     Example: "Tenants may choose a display face from Fraunces, Literata
     or the default." -->

- Base modes: light and dark (in `tokens.json`).
- Additional themes override roles only, in `docs/design/themes/`.
- Tenants may change roles, the logo and the display face from the
  allowed list; never spacing, motion or focus.

## Decisions Log

<!-- What: one dated row per design decision, starting with the initial
     system, appended as the system changes.
     Good: each row names the decision and its reason, and a role or scale
     change also bumps meta.version in tokens.json; a root DESIGN.md
     carried over into this file gets its own line.
     Example: 2026-10-04 | accent.500 lightness 0.58 to 0.54 | primary
     button text fell to 4.3:1 on hover in light mode (contrast.py) -->

| Date | Decision | Rationale |
|------|----------|-----------|
| <today> | Initial design system | Created by design-system from <source>. |
