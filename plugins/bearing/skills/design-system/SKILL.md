---
name: design-system
description: 'Turns a design direction into a design system: oklch tokens, per-stack themes, a component contract, an every-state page and a lint. Use when asked to "set up the design system", "make design tokens" or "lint colours".'
argument-hint: "[DESIGN.md | variant dir | CSS file | brief text] [--stack web|react-native|android|ios] [--lint-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3:*), Bash(python3 *skills/design-system/scripts/contrast.py*), Bash(python3 *skills/design-system/scripts/system_page.py*), Bash(sh scripts/design-lint.sh:*), Bash(bash scripts/design-lint.sh:*), Bash(git diff:*)
---

# design-system

A design direction is prose; a design system is code that a lint can
hold to. This skill writes the tokens once, binds every stack's theme to
them in the form that stack already consumes, and installs a lint that
keeps new literals out. On a full setup it also writes the component
contract and `docs/design/design-system.html`, every component in every
state in both themes, generated from the tokens.

## Inputs

- Direction: `$ARGUMENTS`, else root `DESIGN.md` or `docs/design/DESIGN.md`,
  else `docs/design/variants/*/approved.json`, else the app's current
  styles, else a one-question brief (step 1).
- Stack: `--stack`, else the autopilot profile, else detected
  (`components.json` with react: react-shadcn; `expo`: react-native;
  `build.gradle.kts`: android; `Package.swift` or `*.xcodeproj`: ios).
- This skill's files: `templates/tokens.schema.json`,
  `references/stack-bindings.md` (per-stack forms, sRGB conversion, the
  browser floor), `templates/components.md`, `templates/DESIGN.md`,
  `templates/design-lint.sh`, `scripts/contrast.py` (loads themes's
  `theme-lint.py`; absent, the contrast line says not run),
  `scripts/system_page.py`.
- An existing `docs/design/tokens.json` is updated in place, never
  rewritten without naming the changed roles.

## Scope first

Match the output to the request. "Set up the design system" is the full
procedure below. "Turn DESIGN.md into tokens and hook the app up" is
steps 1 to 7 and the report; "add a check for hardcoded styles" is the
lint section alone. The contract, the page and the guide are offered in
the report when they were not asked for, not produced.

The direction is someone's agreement (a client, a brand owner). Never
rewrite it, move it or replace it with a symlink. Where it cannot be met
as written (a pair that fails contrast, a face that cannot load), ship
the nearest thing that passes and put the change in the report as a
proposal for the direction's owner, with the measurement. Do not change
what the request did not touch: Tailwind's default scales, font weights,
component heights and feature markup stay as they are; a change they
need is listed, not made.

## Read the repo before choosing a value

A generalist writes correct tokens in the wrong form. Settle these from
the files, and name each answer in the report:

1. **What consumes the variables.** Tailwind 3 with colours written
   `hsl(var(--x))` needs HSL channels (`152 64% 30%`); hex, oklch or a
   full `hsl()` there makes every colour silently vanish. Tailwind 4 with
   `@theme inline` takes full colours. Plain CSS takes full colours.
   Native stacks per `references/stack-bindings.md`. The config is not
   the only reader: grep `var(--` across `src` and `index.html` for
   inline styles, chart or canvas code that builds `hsl(${...})` from
   `getComputedStyle`, and a `<meta name="theme-color">` literal; each
   keeps working in the form chosen, or changes with it.
2. **The browser floor.** `browserslist`, `.browserslistrc`, an ADR, the
   README, Vite `build.target`. Safari before 15.4 has no `oklch()` or
   `color-mix()`. A custom property holding hex then oklch does not fall
   back: the oklch value wins and old browsers get no colour. With no
   known floor, or a floor below the feature, ship sRGB; oklch lives in
   `tokens.json` and, at most, in an `@supports (color: oklch(0 0 0))`
   block.
3. **The dark switch.** Three things must name the same selector: what
   the code toggles (`data-theme` attribute, `.dark` class, or only
   `prefers-color-scheme`), the CSS block carrying the dark values, and
   the framework's dark variant (Tailwind 3 `darkMode`, Tailwind 4
   `@custom-variant dark`). A shadcn repo whose toggle sets `data-theme`
   while the CSS says `.dark` has never had a dark mode; fix the mismatch
   and say it was broken. Then first paint: a theme read from storage or
   `matchMedia` and applied in a React effect paints light first for
   every dark user on every load. Set the attribute from an inline script
   in `index.html` before the bundle, or have the CSS apply dark under
   `@media (prefers-color-scheme: dark)` when no choice is stored (the
   `:root:not([data-theme="light"])` form), and say which.
4. **Which document wins.** When a token file, a contributing guide and a
   direction disagree (a spacing scale against "any multiple of 4"),
   follow the one that states its own precedence, else the token file,
   and raise the conflict with both texts quoted.
5. **Where the checks run.** The CI job's image, what it installs and
   what `make check` calls. A check needing bash or python3 does not run
   on `node:*-alpine`; a check's own tests must run there too.

## Steps

1. Resolve the direction: `$ARGUMENTS`, else root `DESIGN.md` or
   `docs/design/DESIGN.md`, else `docs/design/variants/*/approved.json`,
   else the app's current styles read as the de facto system, else ask
   once for a brief (product, audience, one memorable thing, brand
   colour or face). Read it in full; list what it fixes (hue, faces,
   density, shape, devices) and what it leaves free. `--lint-only`: go
   to the lint section.
2. **Measure the direction before designing.** Compute the contrast of
   every pair it implies (brand fill behind its label, brand as link text
   on page and card, brand as focus ring on the page) with
   `scripts/contrast.py` or the WCAG formula. A failing pair keeps its
   hue and moves in lightness until it passes (or swaps the label to a
   dark one); the report gives the direction's ratio, the shipped ratio
   and the alternative.
3. Colour primitives in oklch: accent hue from the direction; neutrals
   at the hue the direction asks for (warm, cool, or the accent's) with
   chroma 0.004 to 0.016; success, warning, danger, info at their own
   hues; each scale 0 to 1000, hue held, lightness varied. Compute every
   sRGB value with the snippet in `references/stack-bindings.md`; a value
   that clips gets less chroma. Refuse the default looks (cream and
   terracotta, near-black and acid green, purple-blue gradients) unless
   the direction names one.
4. Roles for light, then dark designed on its own: surfaces lift with
   lightness, accent one step lighter, chroma down 10 to 20 percent, text
   near white not pure white. Never invert. Text pairs 4.5:1, focus
   rings, borders that carry meaning and icons 3:1, in both modes.
   Include the pairs the components render that the role table misses:
   grep the class strings for each `text-*` on each `bg-*` actually used
   together (`text-muted-foreground` on `bg-muted` is the usual failure:
   muted text tuned to 4.6:1 on the page drops under 4.5 on a tinted
   strip), every opacity-modified fill (`bg-primary/90`,
   `bg-destructive/90`, `bg-secondary/80`: the token composited over the
   surface it sits on) behind its label, link and ring on card.
5. Type and shape. A face the direction names is the face, with its
   fallbacks and how it loads (self-hosted files, a link, or "still to
   do" in the report); a different face is at most a proposal. When the
   direction leaves the face free, choose one for this product rather
   than a default (Inter, Roboto, Arial, system-ui). A mono for data,
   ids and code; tabular figures wherever numbers align (times, money,
   counts). Three to five sizes on one scale with the body size the
   direction gives; two UI weights. Spacing on 4 or 8. Radius as a
   hierarchy (control, container, overlay, full). Elevation 0 to 3 with
   the rule for what may cast a shadow. Motion durations 80, 150, 240,
   400, 700 with standard, enter, exit easings. Touch targets: when the
   direction or the devices mean touch (tablets, kiosks, phones),
   interactive controls reach 44 px (iOS) or 48 dp (Android); measure the
   component sizes the screens use and list the ones below.
6. Write `docs/design/tokens.json` (schema `templates/tokens.schema.json`,
   validate with `uvx --with jsonschema==4.25.1 python -c "import json,jsonschema; jsonschema.validate(json.load(open('docs/design/tokens.json')), json.load(open('<schema>')))"`
   (stdlib Python has no validator; without uv, say "schema: not
   validated"); update an existing file in place with
   `meta.version` bumped and the changed roles named). Measure:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/contrast.py" --tokens docs/design/tokens.json --strict-hex`.
   Its count line is the report's contrast line, verbatim; zero pairs
   checked is a failure; a failed pair goes back to step 4. Then measure
   the extra pairs from step 4 on the values as written in the binding
   (rounded HSL channels are not the hex they came from).
7. Bind each stack per `references/stack-bindings.md`, in the form the
   repo consumes (Read the repo, 1 to 3). On react-shadcn: one file of
   the variables shadcn reads (`src/styles/tokens.css` or `src/index.css`
   itself), replacing the defaults shadcn init wrote, never a parallel
   `--color-*` set the components do not read. Each generated file
   starts with a generated-from header. Then remove what the direction
   rules out from the components it names (a card shadow, a radius),
   inside `src/components/ui`, never per feature.
8. Full setup only: `docs/design/components.md` from
   `templates/components.md` (each entry names its `src/components/ui`
   component and allowed variants; a missing need becomes a variant
   there; `- States:` stays one comma list on one line). Then
   `system_page.py tokens-css`, `build` and `check` (paths in the
   script's help; `build --fonts-css <file>` links the product's own
   `@font-face` stylesheet, and `--google-fonts` is only for a product
   that loads its faces from Google); `check` must exit 0; open the page
   in both themes. On react-shadcn the binding in `globals.css` or
   `index.css` is written by hand from `tokens.json` (no generator writes
   shadcn's names yet); compare its roles with `tokens.css` after each
   change.
   Write `docs/design/DESIGN.md` from `templates/DESIGN.md` as the
   system's guide, linking to the direction; when the repo has no root
   `DESIGN.md`, add a relative symlink to the guide so gstack finds it.
9. The lint (next section) and `make check`.

## The lint

Install `templates/design-lint.sh` as `scripts/design-lint.sh` (POSIX sh
and awk: runs on alpine, busybox and macOS without bash, python3 or
node) and add `design-lint` under `check` in the Makefile. It strips
comments, skips the token and generated files, and counts per occurrence:
hex, `rgb()`, `hsl()`, `oklch()`, `color-mix()` and named colours;
spacing and font sizes off the scale, including px inside style-object
strings (`padding: "6px 12px"`), rem at 16 px, and Tailwind arbitrary
values; shadows on non-pressable elements; raw `<button>`, `<input>`,
`<table>` and friends outside `components/ui` (`DESIGN_LINT_LIBRARY` for
another library folder); one-off font families.

1. Gate only what was asked: set `DESIGN_LINT_RULES` in the Makefile
   (colour, spacing, font-size, shadow, raw, family). "Colours and px"
   means `colour spacing font-size`; the other rules are offered in the
   report, because a rule nobody agreed to fails someone's next merge
   request. On-scale literals pass; the gate is for values off the scale.
   Check the scale source line it prints: the scale must be the one the
   team means (step 4 of Read the repo). Set `DESIGN_SPACE_SCALE` and
   `DESIGN_FONT_SCALE` in the Makefile when the tokens do not state it.
   Vendored code (`vendor/`, `*.min.css`, a header saying it is copied
   from a package) is excluded, not baselined: it is not the team's debt
   and its next upgrade would fail the gate.
2. Read every finding before baselining. A false positive is a lint bug:
   fix the template's pattern or exclude the path, never baseline it.
   Report today's debt per category with file and line.
3. Existing debt: fix a literal only when a token holds the same value
   in both themes; a literal with no matching token stays as debt (a
   near match is a visual change, and needs saying). Record the rest with
   `sh scripts/design-lint.sh --write-baseline`. The baseline is keyed by
   file and literal with a count, so a new literal anywhere, including a
   second copy on an old line, fails, and paying a debt does not make
   room for another. A total allowance (`ALLOW_COLOR=7`) is not a ratchet.
   Paying a debt also fails until the baseline is lowered in the same
   change; tell the team that, with the command, in the report.
4. Prove it: add a new colour and an off-scale value in a scratch file,
   run `make check`, see it fail, remove them. If the check has tests,
   they run under `make check` in the CI image too.

## Output contract

Changed, Verified, Not done, Noticed. Lead with anything that was broken
before (dark mode never switching, variables in a form the config
cannot read). Then:

```
direction: <source>; stack: <binding form, e.g. Tailwind 3 HSL channels>; floor: <browsers, source>
dark switch: <what toggles> = <CSS selector> = <framework variant>
contrast: <contrast.py count line, verbatim>; extra pairs: <hover, link on card, ring> <ratios>
proposals for the direction's owner: <each change with measured before and after>
design-lint: <count line, verbatim>; baseline <n> keys; new-literal proof: failed as expected | not run
gate: make check: passed | failed (<target>) | no Makefile
not run: <build, device on the browser floor, CI pipeline> (say which; never claim them)
```

## Gotchas

- `hsl(var(--x))` in a Tailwind 3 config and a hex in `--x` compile
  without error and render nothing. Grep the config before writing a
  value.
- Opacity modifiers (`bg-primary/90`) are new colours: a 90 percent
  primary over white is lighter than the token and can drop a passing
  label below 4.5:1. Measure the composite, or give hover its own token.
- `@theme` without `inline` snapshots values at build time and breaks
  runtime theme switching; `inline` keeps the cascade.
- Tailwind's default palette stays reachable unless `--color-*: initial`
  (v4) or `theme.colors` replaced (v3); that is a scope decision, so it
  is proposed, not done, when the request did not ask.
- React Native has no oklch and no CSS cascade: the provider supplies
  `roles[mode]` for `StyleSheet` code as well as the class.
- Material 3 dynamic colour replaces the derived palette with the
  wallpaper's; leave it off unless the direction asks.
- A SwiftUI `Font.custom` without `relativeTo:` disables Dynamic Type.
- The lint is pattern-based: a colour built in a variable named `brand`,
  or a value split across lines, is missed. Review the diff too.
- The design-system page is generated; change the tokens or the
  contract and build again, never hand-edit it.
- A hover or active specimen is drawn with an `is-*` class because a
  static page cannot hold the pointer; a component that styles only
  `:hover` still needs the class rule.
- Other inputs: gstack `design-consultation` writes a direction as
  DESIGN.md prose and GSD `gsd-ui-phase` writes a UI-SPEC per phase;
  either is read as the direction.
