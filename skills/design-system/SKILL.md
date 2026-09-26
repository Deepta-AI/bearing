---
name: design-system
description: 'Turns a design direction into a design system: oklch tokens, per-stack themes, a component contract, an every-state page and a lint. Use when asked to "set up the design system", "make design tokens" or "lint colours".'
argument-hint: "[DESIGN.md | variant dir | CSS file | brief text] [--stack web|react-native|android|ios] [--lint-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(python3:*), Bash(python3 *skills/design-system/scripts/contrast.py*), Bash(python3 *skills/design-system/scripts/system_page.py*), Bash(bash scripts/design-lint.sh:*), Bash(git diff:*)
---

# design-system

A design direction is prose; a design system is code that a lint can
hold to. This skill writes the tokens once, derives every stack's theme
file from them, states what each component may consume, and installs
the lint that keeps literals out of the codebase. It also draws the
system: `docs/design/design-system.html` shows every token and every
component in every state, in the light and the dark theme side by side,
generated from the tokens so the page cannot drift from them.

## Inputs

- Direction: `$ARGUMENTS` when it names a file or directory; if absent,
  the root `DESIGN.md` or `docs/design/DESIGN.md` (gstack shape); if
  absent, `docs/design/variants/*/approved.json` or the newest variant
  directory; if absent, the app's own styles (`src/index.css`,
  `tailwind.config.*`, `ui/theme/*.kt`, `Theme.swift`) read as the
  current de facto system; if none, ask once for a brief (product,
  audience, the one memorable thing, any brand colour or face). Say
  which source was used in `meta.source`.
- Stack: `--stack`; if absent, the ui stack in the autopilot profile; if
  absent, detected from `package.json` (`react` with a `components.json`,
  or no UI code yet, means `react-shadcn`, the default; `expo` means
  react-native), `build.gradle.kts` (android),
  `Package.swift` or `*.xcodeproj` (ios); several matches generate every
  matching binding; none: tokens and docs only, and the report says so.
- Schema: `templates/tokens.schema.json`; conversion notes:
  `references/stack-bindings.md`; contract and guide templates:
  `templates/components.md`, `templates/DESIGN.md`; lint:
  `templates/design-lint.sh`; contrast: `scripts/contrast.py` in this
  skill, which loads `theme-lint.py` from themes in the same plugin
  (absent: the script exits 1 and the contrast line says not run).
- Visual page: `templates/design-system.html` (the specimens, one per
  state per component) and `scripts/system_page.py` (writes
  `docs/design/tokens.css`, builds the page, and checks it against the
  "- States:" lines in components.md); Python 3 only. An existing
  `docs/design/design-system.html` is rebuilt, never hand-edited; a
  specimen the product needs and the template lacks is added to the
  built page and listed in the report.
- Existing `docs/design/tokens.json`: read and updated in place with
  `meta.version` bumped when a role or scale changes; never rewritten
  from scratch without saying which roles changed.
- Makefile: `design-lint` added under `check` when a Makefile exists;
  if absent, the script is still installed and its command printed
  (`new-repo` or `onboard-repo` bring the Makefile).

## Steps

1. Resolve the direction and the stack as in Inputs. Read the direction
   in full. List what it fixes (hue, faces, density, mood) and what it
   leaves free. `--lint-only`: skip to step 9.
2. Derive the colour primitives in oklch. Accent hue from the direction;
   neutral at the same hue with chroma 0.004 to 0.016; success, warning,
   danger, info at their own hues. Each scale runs 0 to 1000 with hue
   held and lightness varied. Compute every hex fallback with the
   snippet in `references/stack-bindings.md`; a value that clips gets
   less chroma. Refuse the default looks (cream and terracotta,
   near-black and acid green, purple-blue gradients) unless the
   direction names one by its own words.
3. Assign roles for light, then design dark on its own: surfaces lift
   with lightness, accent one step lighter, chroma down 10 to 20
   percent, text `neutral.0`. Never invert. Aim every text-on-surface
   pair at 4.5:1 and every edge and focus pair at 3:1; step 4 measures
   them.
4. Type: one UI face for every screen and a mono for data, ids and code,
   chosen for this product; a display face only when the direction needs
   one, and then for headings alone. Never Inter, Space Grotesk, Roboto,
   Arial, Helvetica, Open Sans, Lato, Montserrat or Poppins, and never
   system-ui as the face. Two faces that both carry body text is two
   systems: screens that mixed four faces read as four
   products. Three to five
   sizes on one scale, two weights for UI (a third only for display),
   line heights and tracking per role. Spacing on 8 with the single 4
   half step. Radius as a hierarchy (control, container, overlay, full).
   Elevation levels 0 to 3 with the rule text verbatim. Motion durations
   80, 150, 240, 400, 700 with standard, enter, exit and spring
   easings. Breakpoints, z layers, focus ring. Write
   `docs/design/tokens.json` and validate it against the schema with
   `python3` (`jsonschema` when installed; else a key walk over
   `required`). Print token and role counts. Then measure contrast with
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/contrast.py" --tokens docs/design/tokens.json --strict-hex`.
   It resolves every role in both modes through themes's
   `theme-lint.py` (the kit's one contrast calculator) and checks the
   same pair table themes uses. Its count line is the report's
   contrast line, verbatim; the line is never written from judgement.
   A failed pair goes back to step 3 for that role and the script runs
   again. Zero pairs checked is a failure.
5. Generate one binding per detected stack from
   `references/stack-bindings.md`. react-shadcn, the default: the
   variables shadcn/ui reads (`--background`, `--foreground`, `--card`,
   `--popover`, `--primary`, `--secondary`, `--muted`, `--accent`,
   `--destructive`, `--border`, `--input`, `--ring`, `--chart-1..5`,
   `--sidebar-*`, `--radius`, `--font-sans`, `--font-mono`) written from
   the roles in `src/styles/tokens.css`, light on `:root`, dark on `.dark,
   [data-theme="dark"]`, imported before the `@theme inline` block of
   `src/index.css`, whose shadcn defaults it replaces. One namespace: a
   parallel `--color-*` set beside shadcn's variables leaves every
   component on the defaults, which is how the first prospector screens
   drifted. Other web stacks: `src/styles/tokens.css` imported
   first from `src/index.css` (custom properties, hex then oklch,
   `data-theme` and `prefers-color-scheme` cascade, `@theme inline`,
   focus ring, reduced-motion zeroing); `src/theme/theme.ts` plus
   `tailwind.config.js` wiring; `ui/theme/Color.kt`, `Type.kt`,
   `Shape.kt`, `Theme.kt`; `App/Theme/Theme.swift`. Each file starts
   with the generated header. Never hand-edit one afterwards.
6. Write `docs/design/components.md` from `templates/components.md`,
   replacing every placeholder with this system's values and cutting
   any component the product will never have (say which). Each entry's
   `- States:` line stays one comma list on one line. On react-shadcn
   each contract entry names its `src/components/ui` component and the
   variants it may use (Button: default, secondary, outline, ghost,
   destructive; sizes sm, default, icon), and a need the inventory lacks
   becomes a variant added in `src/components/ui`, never a one-off in a
   feature. Motion is `motion-design`'s: durations and easings in the
   tokens, the moments in `docs/design/motion.md`.
7. The shared tokens file and the visual page. Write the bundle's one
   colour file:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" tokens-css --tokens docs/design/tokens.json --out docs/design/tokens.css`.
   Every screen and page under `docs/design/` links it; none copies it.
   Then build the page from `templates/design-system.html`:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" build --tokens docs/design/tokens.json --components docs/design/components.md --out docs/design/design-system.html`.
   It fills the foundations from tokens.json (every role swatch in both
   themes with its value, type roles, space, radius, elevation, motion),
   draws each component's specimens in a light pane and a dark pane, and
   cuts the components the contract cut. Replace the template's sample
   copy with this product's words where a specimen shows content. Then
   the gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" check --page docs/design/design-system.html --components docs/design/components.md`.
   It fails on a state with no specimen in either theme, a colour
   literal, a missing tokens.css and zero components; fix and rerun
   until it exits 0. Open the page in both themes before reporting.
8. Write `docs/design/DESIGN.md` from `templates/DESIGN.md` with every
   angle-bracket filled and the Decisions Log started. Make the root
   `DESIGN.md` a relative symlink to it so gstack's skills find it; a
   root file with content is the direction (step 1) and is replaced by
   the symlink after its content is carried over, with a log line.
9. Install `scripts/design-lint.sh` from `templates/design-lint.sh`
   (it also counts raw `<table>`, `<button>`, `<input>`, `<select>`,
   `<textarea>` and `<dialog>` in feature code and one-off font families;
   the roots include `web/src`),
   add `design-lint` to the Makefile under `check`, run it, and print
   the tail. A first run on an existing codebase usually fails; set the
   allowance in the Makefile to today's counts, name them in the report
   as debt, and never raise an allowance later.
10. Run `make check` when it exists and print the contract.

## Output contract

```
## Design system: <product> (source: <DESIGN.md | variant | css | brief>, stacks: <list>)
tokens.json: v<n>, <T> tokens, <R> roles x 2 modes, <P> primitive scales, schema: valid | <errors>
contrast: <N> pairs checked (light <L>, dark <D>), <K> below minimum (must be 0), AAA body pairs: <M>   (contrast.py, verbatim)
bindings: <path per stack>
components.md: <C> components, <S> states
tokens.css: <tokens-css count line, verbatim>   (docs/design/tokens.css, linked by every page)
design-system.html: <system_page.py check count line, verbatim>   (open the file)
DESIGN.md: docs/design/DESIGN.md (root symlink: created | existing | skipped: <why>)
design-lint: <F> files, <c> colours, <s> spacing, <f> font sizes, <d> shadows (allowance c/s/f/d) passed | failed
gate: make check: passed | failed (<target>) | no Makefile
```

## Gotchas

- Hex fallbacks are computed from the oklch value, never typed from
  memory; a fallback that drifts shows up only on old browsers.
- `@theme` without `inline` snapshots the value at build time and
  breaks `data-theme` switching; `inline` keeps the cascade.
- Tailwind's default palette stays reachable unless `--color-*:
  initial` is declared; `bg-blue-500` compiling is a lint miss, not
  a pass.
- React Native has no oklch and no CSS cascade: the provider must
  supply `roles[mode]` for `StyleSheet` code as well as the class.
- Material 3 dynamic colour replaces the derived palette with the
  wallpaper's; leave it off unless the direction asks.
- A SwiftUI `Font.custom` without `relativeTo:` disables Dynamic Type.
- The lint is grep-based: a colour in a variable named `brand` or a
  shadow on a `div` with an `onClick` in the next line is missed.
  Review the diff, not only the counts.
- The design-system page is generated. A hand edit is lost on the next
  build and lets the page drift from tokens.json; change the tokens or
  the contract and build again.
- A specimen for hover or active is drawn with an `is-*` class because
  a static page cannot hold the pointer there; a component that styles
  only `:hover` still needs the class rule, or the specimen lies.
- Alternates: gstack `design-consultation` proposes the direction and
  writes DESIGN.md prose; GSD `gsd-ui-phase` writes a UI-SPEC contract
  per phase. Neither emits tokens as code or a lint; this skill reads
  both as input.
