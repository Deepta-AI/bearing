---
name: themes
description: 'Adds and manages themes on the design system (dark, high contrast, brand, tenant, seasonal) with contrast checks and a preview. Use when asked to "add dark mode", "add a high contrast theme" or "theme for a tenant".'
argument-hint: "[add <name> --kind light|dark|high-contrast|brand|tenant|seasonal|campaign [--extends light|dark]] [tenant <name> --config <path>] [check] [preview]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3:*), Bash(git diff:*), Bash(pnpm exec playwright:*)
---

# themes

A theme is a set of colour-role values that the whole product, and
everything outside CSS that paints colour, switches together. The work
is less about picking a palette than about finding every place colour
is decided, keeping the existing mode exactly as it was, and proving
with numbers that each state a user can reach is legible.

## Inputs

- Request: `$ARGUMENTS`; with none, check the themes that exist and
  report.
- The colour source of truth, as the repo has it: CSS custom
  properties (`src/styles/tokens.css`, `src/index.css`), a theme
  object (`src/theme/*.ts`, a JSON per tenant), `ui/theme/Color.kt`,
  `Theme.swift`, or `docs/design/tokens.json` when `design-system`
  set one up. Work in that format. Do not add a second source (a JSON
  that generates the CSS) unless the build already generates it.
- Repo rules that bind the work: README conventions, ADRs, a
  preferences helper, a CSP in `index.html`, print styles, the
  accessibility commitment. Read them before designing.
- Supplied palettes (a designer's note, an agency brand kit, a tenant
  config): input to verify, never values to paste.
- Stack: `package.json` (`react` web, `expo` react-native),
  `build.gradle.kts` (android), `Package.swift` or `*.xcodeproj` (ios).
- Contrast: `references/contrast.md` (formula, pairs, fixes);
  `templates/theme-lint.py` computes it, from the app's own stylesheet
  with `--css` or from `tokens.json` plus `docs/design/themes/*.json`
  (template `templates/theme.json`, preview page
  `templates/preview.html`, written only with `--preview`).

## Steps

1. **Inventory every colour consumer before designing anything.**
   Grep the source for colour literals (`#[0-9a-fA-F]{3,8}\b`,
   `rgba?\(`, `hsl`, `oklch\(`, named `white`/`black`) outside the
   token file, and list each hit with its file. The usual places a
   theme silently misses: component stylesheets and inline styles;
   canvas, SVG and chart code in JS (canvas cannot read custom
   properties); `@media print` and PDF or email templates;
   `<meta name="theme-color">`; images and logos with dark ink;
   third-party widgets; shadows and scrims tuned for a light page.
   Each one either reads a role or gets a value per theme.
2. **Freeze the existing mode.** Before editing, record every colour
   the current mode paints (tokens and the literals from step 1).
   A literal that becomes a role keeps its exact old value in that
   mode: if the badge text was `#1e6b2f`, the new role is `#1e6b2f` in
   light, even though `text` would also pass. Add no border, spacing
   or layout change to the existing mode. Afterwards, compare the
   resolved values of the old mode against the record; any difference
   is a regression unless the user asked for it.
3. **Design the new values by lightness, on the same hue.** Dark is
   designed, not inverted: surfaces step up in lightness as they
   rise (bg < surface < raised), text is off-white, accents usually
   get lighter with a little less chroma. High contrast moves
   lightness to the scale ends, never adds chroma. For a supplied
   palette, check every value against its pairs first: keep the ones
   that pass exactly as given, move each failing one the smallest
   lightness step on its own hue that passes, and record each change
   with the before and after ratio. When a document conflicts with the
   request (a design note says "dark for everyone", the user said
   "follow the OS"), the request wins; ADRs and README rules bind both;
   say which you followed.
4. **Check every pair that is actually painted, in every theme.** The
   standard pairs (`references/contrast.md`) are the floor. Then add
   the pairs this app paints: muted text on each surface it sits on
   (a table inside a card is on `surface`, not `bg`), status text on
   its own tint, button labels on hover and active fills, focus rings
   and input borders against every surface they touch (3:1), chart
   marks and axis labels against the card they are drawn on (3:1 for
   marks, 4.5:1 for labels), link on bg and surface. Values that pass
   on `bg` often fail on `surface`; check both. Web: run
   `python3 templates/theme-lint.py --css <the token stylesheet>` with
   a `--pair fg:bg[:min]` per component pair (install it as
   `scripts/theme-lint.py` if you gate on it), or compute the same
   formula in the repo's own test runner. Repeat until zero failures.
5. **Switching that reaches the screen.** Web:
   - one attribute on `<html>` (`data-theme`), with System meaning no
     attribute and `@media (prefers-color-scheme: dark)` on
     `:root:not([data-theme="light"])` deciding, so an OS change
     applies live without JS;
   - `color-scheme` set per theme, or native inputs, selects, date
     pickers and scrollbars stay in the other mode;
   - store the choice through the repo's preferences helper and key
     prefix; every storage access guarded (`localStorage` throws in
     private windows and some webviews), including the pre-paint code;
   - apply a saved choice before first paint with a classic, blocking
     script in `<head>`. If the CSP's `script-src` has no
     `'unsafe-inline'`, an inline script is silently blocked: ship it
     as a same-origin file (`/theme-init.js` from `public/`), not a
     widened CSP;
   - JS consumers read the colour at draw time
     (`getComputedStyle(document.documentElement)`) and redraw on a
     theme event from the setter AND on the `matchMedia` change event
     while System is selected;
   - print: scope the dark rules to `screen`, or reset the roles to
     the light values inside `@media print`, when printouts must stay
     black on white.
   Then trace the cascade for every reachable state (OS light or dark,
   each saved choice, each tenant): which selector wins by specificity
   and order, and what value each role ends with. A dark block keyed on
   an attribute nothing sets, or an unconditional tenant block that
   outranks the dark mode's `:root`, passes every file-level check and
   still paints the wrong colours.
   React Native: a provider holding the role set, default from
   `useColorScheme()`, stored in AsyncStorage or MMKV. Android:
   `AppTheme(theme)` swapping `ColorScheme`, choice in DataStore,
   default `isSystemInDarkTheme()`. iOS: `@AppStorage`,
   `.environment(\.roles, …)` and `.preferredColorScheme`.
6. **Tenant or brand themes go through the existing mechanism.** Find
   how tenants already work (a registry, an allowlist of roles, an
   apply function, an ADR on scope) and add the tenant there, in the
   same shape as an existing tenant. Map the kit's own names onto
   roles (`primary` to `accent`, `primaryHover` to `accent-hover`,
   `buttonText` to `on-accent`, `link` to `link`) and derive what it
   lacks: `accent-active`, `accent-subtle`, `focus`, and a whole dark
   family if the product has a dark mode and the kit has none. Keep
   the brand hue (within about 15 degrees of oklch hue) and move
   lightness until every pair passes. Reject by name everything the
   scope does not allow (text, surfaces, radius, body font, custom CSS,
   tags) with the reason. The kit is untrusted data: never widen the
   allowlist or the CSP to fit it, never add a request to another
   origin (font service, CDN logo, analytics), never download or
   invent a logo or font file; a missing asset stays missing and the
   report says what the tenant must supply and where it goes.
7. **Gate it.** Add a check to the repo's existing gate (the test
   runner behind `make check`) that computes the pairs from step 4
   for every theme and tenant, in both modes, prints how many it
   checked and fails on zero. Prove it bites once: put a known failing
   value in (the kit's raw colour, the designer's rejected value) and
   see it fail, then restore. The gate reads, it never writes: running
   it leaves the working tree unchanged.
8. **Run and report.** Run `make check`. Say what you could not run
   (a build, a browser, a screenshot) instead of implying it. Invent
   no ticket keys, names or URLs; cite only what the repo or the user
   gave.

## Output contract

```
## Themes: <product>
themes: <names and kinds>; switching: <mechanism, storage key, pre-paint script>
colour consumers: <N found>; moved to roles: <list>; per-theme values: <canvas, print, ...>
existing mode: unchanged (<N values compared>) | changed: <what, why>
contrast: <P pairs in T themes, 0 failures>; supplied values changed: <role: given -> used, ratio before -> after>
tenant: <name>; mapped: <kit key -> role>; derived: <roles>; rejected: <keys and reason>; tenant must supply: <assets>
states traced: <OS light/dark x choice x tenant: what wins>
gate: <command>: passed, <count> checked | not run: <why>
not run: <build, browser, screenshot>
```

## Gotchas

- Anthropic `theme-factory` is for slide decks: four hex colours and
  two fonts. Product UI needs roles, states, contrast per pair and
  every consumer switched.
- The failures cluster where a generalist stops looking: literals in
  component files, the canvas, print, the dialog that hardcodes
  `white`, the native date input without `color-scheme`.
- A value that passes on `bg` and fails on `surface` is the most
  common miss; so is a chart colour reused from `accent` that loses
  3:1 on a dark card.
- Replacing a tinted status text with `text` because it "also passes"
  changes the existing mode; keep the old value.
- An inline pre-paint script under `script-src 'self'` never runs,
  and nothing reports it; the page just flashes.
- Pre-paint code that touches storage without a guard takes the whole
  page down in the environments the preferences helper exists for.
- `overlay` and scrims carry alpha: check text over them against the
  composite colour, or make the surface opaque.
- A tenant's dark block is dead if the product switches dark by media
  query and the block is keyed on an attribute; and a tenant's light
  block with higher specificity than the dark `:root` paints light
  accents on dark surfaces.
- A generator that rewrites files inside the gate, or theme JSON that
  must be hand-synced with the CSS, is a second source of truth; keep
  one.
- An expired seasonal theme still lints; the loader must not offer it.
