---
name: design-directions
description: 'Produces three genuinely different visual design directions over the real screens, scores them and records the choice. Use when asked for "design directions", "three design options" or "which look should we go with".'
argument-hint: "<feature> [--screens S-01,S-03] [--round 2] [--unattended]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 -m http.server:*), Bash(python3 *skills/design-critique/scripts/evidence.py*), Bash(python3 *skills/design-critique/scripts/pairs.py*)
---

# design-directions

Three variants exist so the user chooses between real alternatives, not
shades of one idea. The test is the swapped headline: if the headline of
one page could sit in another unnoticed, that pair failed. Each page is a
working artefact with real copy, visible focus and one motion moment,
built inside the project's own rules. `references/design-doctrine.md`
governs every choice and is read in full before the plan is written.

A direction is judged by the people who use the screen, not by its name.
Every direction says which user and which condition it serves first (a
dispatcher at a desk all day, a driver in sun on a phone, a patient at
arm's length) and where it is weakest for the others.

On React with shadcn/ui and Tailwind, a direction is a theme, not a page:
it overrides the variables the components already read, and the real
screens render with it switched on. The comparison is then like for like:
the same screens, the same components, three looks. A direction the
component set cannot render is not a direction.

## Inputs

- Feature: looks in `$1`; if absent, asks one question.
- Screens and copy: the newest `docs/design/flows/<feature>/flows*.md`
  (inventory, states, copy, privacy and timing rules); if absent,
  `docs/product/backlog.md` stories; if absent, the routes and screens in
  the code; if absent, asks once for a one-paragraph brief. `--screens`
  limits the screens; the default is the happy path's first screen plus
  one state screen (empty, delayed or error).
- Users: README, `docs/product/PRD.md`, product copy: who uses the
  screen, on what device, where, for how long.
- Project constraints, which override every default in this skill:
  accepted ADRs under `docs/adr/`, the Content-Security-Policy (an
  `index.html` meta tag or server headers), the README's hardware and
  deployment notes, brand notes. Look for: where fonts may come from (a
  `font-src 'self'`, a firewalled or offline deployment), a fixed device
  size or orientation, light only, a contrast ratio above WCAG AA, a
  touch-target floor, a motion limit, privacy rules on what a screen may
  show. A brand note never outranks an Accepted ADR.
- Design system: `DESIGN.md`, `docs/design/tokens.json`, the token CSS
  file. When they disagree, the newest Accepted ADR and the file the code
  loads win, and the stale document is named in the output. A system
  freezes colour and faces; variants then differ in layout, hierarchy,
  type scale within the allowed faces, density and the motion moment.
- Previous round: `docs/design/variants/<feature>/approved.json`; with
  `--round 2` its chosen traits are fixed.
- Screenshots: the gstack browse binary
  `~/.claude/skills/gstack/browse/dist/browse` when executable, or a
  local headless Chrome; otherwise none are taken and the output says so.
- Measurement: `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py`
  (shots at 375, 768, 1440 in light and dark) and
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py`
  (contrast of every text pair in static pages); Python 3 only.
- Templates: `templates/variant.html`, `templates/board.html` (HTML
  targets only).
- Target: the ui stack in the autopilot profile, else a React app with
  `components.json` or no UI code yet means react-shadcn; any other stack
  uses the HTML variants.
- Reference looks the user names (Stripe dashboard, Linear): each
  direction states which trait it borrows and never copies a brand.
- `--unattended` (autopilot): no one chooses; step 10 scores the three.

## Steps

1. Read the inputs; print each as read or absent, then list the
   constraints found with their source (for example "fonts: self-hosted
   only, ADR-0003 and CSP font-src 'self'"; "device: 1080 x 1920
   portrait, light only, README and ADR-0005"). They replace the
   defaults: widths 375, 768 and 1440 become the device size when the
   product runs on one; both themes become one when a rule says so; 44 px
   targets, 4.5:1 and 200 to 700 ms motion become the project's numbers
   when stricter. Zero screens and no brief: stop with "provide flows,
   stories, code with screens, or a brief".
2. Audit what the directions will sit on, before designing. Each finding
   goes in the output, even when it is outside the feature:
   - Colours outside the tokens: Grep the screens and the components they
     render for fixed palette classes (`bg-amber-50`, `text-sky-800`),
     hex, `rgb(` and `oklch(` literals and inline `style=`. No theme
     reaches them, and they usually stay light in dark mode.
   - Text tokens, frozen or not, against the project's contrast rule:
     compute every text colour on every surface it can sit on, and every
     label on its fill (white on a bright brand colour is the usual
     failure). A token that fails is not used for that role; name it.
   - Field edges and control boundaries need 3:1 against what surrounds
     them (WCAG 1.4.11); a pale line token rarely has it.
   - Target sizes as rendered: read the component's real height (`h-9`
     is 36 px) and check inline elements, where `min-height` does nothing
     on an `a` that is not a block or flex box.
   - Fonts: does anything load the faces the tokens name (an
     `@font-face`, a Fontsource import, a file under `public/` or
     `static/`)? A face that is named but never loaded renders as the
     fallback everywhere.
   - Privacy: does a live screen or sample show what the flows forbid (a
     typed birth year in plain view, a full name, a reason for a visit)?
3. Design plan: read `references/design-doctrine.md`. One paragraph per
   variant: the direction row, the user and condition it serves first and
   its weak spot, the faces (only faces the constraints allow), four to
   six colours in oklch or hex each with its reason, the layout rhythm in
   one sentence plus an ASCII wireframe, the signature element, the
   motion moment. Under a design system the colour and face lines cite
   the tokens, and the output says which axes were frozen.
4. Distinctness gate, before any code: every pair differs on display
   family, palette temperature and layout rhythm (under a system: layout,
   hierarchy and type scale). Then the swapped-headline test per pair. A
   failing pair: rewrite the weaker brief from another row and test
   again. This is a judgement, not a measurement; the output says so.
5. Generic-default pass: write the default answer to the same brief. A
   plan line that matches it (the three AI looks, a stat-and-gradient
   hero, Inter or Space Grotesk as display) is revised; the count goes in
   the output.
6. react-shadcn build (instead of step 7):
   - One file per direction, `src/design/variants/<n>-<name>.css`,
     overriding `--font-sans`, `--font-mono`, the type scale, the colour
     roles shadcn reads (`--background`, `--foreground`, `--card`,
     `--primary`, `--primary-foreground`, `--muted`, `--muted-foreground`,
     `--accent`, `--border`, `--input`, `--ring`, `--destructive`, and
     `--sidebar-*`, `--chart-*` where used), `--radius`, spacing, shadows
     and motion easing.
   - Selectors match where the app sets things. Read the theme code for
     the element that gets the dark class or attribute, put the direction
     attribute on the same element, and write light as
     `:root[data-variant="<n>-<name>"]` and dark as
     `:root[data-variant="<n>-<name>"].dark` (or `[data-theme="dark"]`,
     whichever the app sets). A bare `[data-variant]` ties `:root` on
     specificity and wins only by import order, which a refactor breaks.
     Dark under `@media (prefers-color-scheme)` alone is wrong when the
     app stores the user's choice.
   - The default look is untouched: `:root` and `.dark` keep their
     values, and nothing applies without the switch.
   - The switch: the project's design gallery when one exists. Without
     one, add a dev-only switch (read `?variant=` in the entry file behind
     `import.meta.env.DEV`, set the attribute on the root element, import
     the direction's CSS) so the real routes render each direction. Print
     how to view each one.
   - Colours found in step 2 move onto variables whose defaults equal the
     old values (the default look stays the same) so each direction can
     set them, or they are listed as not following the directions.
   - Density and shape go through variables, or through neutral hook
     attributes (`data-slot`, `data-part`) styled under the direction's
     selector; never per-direction class names or conditionals in
     components. A direction restyles: it adds no content, fields,
     computed values or controls.
   - Targets: when phones are among the users, every direction reaches
     44 px (or the project's floor) at phone width.
   - Fonts: the faces already bundled, or new ones as Fontsource packages
     or self-hosted files, never a third-party host when the CSP or an ADR
     forbids it; the CSP is never loosened. Packages added but not
     installed are said to be not installed; a face with no self-hostable
     source is dropped with the reason.
   Then step 8, and continue at step 9.
7. HTML targets. Build `<n>-<name>.html` per variant from
   `templates/variant.html`: tokens on `:root`, the screens as sections
   with the flows' copy word for word including the state screen, at the
   project's sizes (the device size and orientation when fixed; else no
   horizontal scroll at 375, 768 and 1440 and no half-width desktop
   column beside dead space), dark only when the product has dark,
   `:focus-visible` on every control, the motion moment behind the
   reduced-motion guard and inside the project's limit, the theme toggle
   as the only script. Fonts load the way the product can load them: a
   Google Fonts link only when no constraint forbids it and the device
   can reach it; otherwise self-hosted, or the fallback stated. Sample
   data follows the flows' privacy rules, and a sensitive input shows no
   typed value in plain view. Copy not in the flows is written and marked
   `proposed`.
8. Check each direction and fix before showing; record each fix:
   - Contrast, computed from the values written, in every theme the
     product has, against the project's ratios. HTML pages:
     `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py" --need <body ratio> <n>-<name>.html...`
     (its large-text threshold is 3:1; apply a stricter project rule by
     hand). react-shadcn: compute foreground on background and card,
     primary-foreground on primary, muted-foreground on background, card
     and muted, and every status pair, per direction and theme. Print the
     count; zero pairs checked is a failure, not a pass.
   - Targets, text floor, motion duration and the reduced-motion guard,
     from the CSS values.
   - The doctrine's hard rules and anti-slop list.
9. Screenshots when a browser runs. Responsive products:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base <folder or dev URL> --out docs/design/variants/<feature>/shots <page>...`
   then `check` with the same `--out` and pages; read every PNG; fix and
   re-shoot until `check` exits 0. A fixed device or a single theme does
   not fit `check`: shoot at the device size in the product's theme and
   say `check` does not apply. When the app cannot run (dependencies
   absent, no network), say nothing was built, run or seen, and never
   describe how a direction looks on screen.
10. Board `docs/design/variants/<feature>/index.html` from
    `templates/board.html` (react-shadcn: a README with the view link per
    direction instead): one column per variant with the user it serves,
    the shots or iframes at the product's size, rating 1 to 5, comment,
    remix field, chosen radio. The board chrome stays neutral, loads
    nothing from another host and posts nothing. Serve it with
    `python3 -m http.server 0 --bind 127.0.0.1 --directory <folder>` only
    when someone will open it now; else say to open the file.
    Record `approved.json` (`round`, `date`, `recommended`, `chosen`,
    `ratings`, `comments`, `remix`, `notes`). `chosen` stays null until
    the user picks: a recommendation goes in `recommended`, never in
    `chosen`, and no direction becomes the default. When feedback
    arrives, repeat it back in one paragraph before writing it.
    `--unattended`: score each direction with the ten categories of
    `../design-critique/references/review-checklist.md`, write `scores`,
    `chosen` (the highest), `chosen_by: "score"` and one line per
    direction on why it won or lost; the user can overrule it at the
    merge request.
11. Round two on request: variants 4 to 6 keep the chosen traits (the
    remix spec, or the chosen variant's axes) and vary the rest; steps 4
    to 10 again; the board keeps round one below.
12. Print the output contract; name `design-critique` as next.

## Output contract

```
## Design variants: <feature> (round <n>)
Path: docs/design/variants/<feature>/ (and src/design/variants/ on react-shadcn)
Screens rendered: N (from flows | stories | code | brief)
Constraints: <each, with its source> | none found
System: <source followed> (frozen: colour, faces; stale: <doc> | none) | none
1-<name>: serves <user, condition>; <face> / <temperature> / <rhythm>
2-<name>: ...
3-<name>: ...
Distinctness: <d> of 3 pairs judged distinct (judged, not measured; retries: K)
Contrast: <N> pairs checked, <K> below the project's ratio | not checked
Audit: <colours outside tokens, failing tokens, targets, fonts, privacy> | none
Screenshots: <evidence.py check line> | <N> at <device size> | not taken (<why>; nothing seen on screen)
View: <board path or URL | how to switch each direction on>
Recommended: <n>-<name> (<reason tied to the users>); chosen: pending | <n>-<name>
Next: design-critique docs/design/variants/<feature>
```

## Gotchas

- Three variants of one idea is one variant. Two palettes sharing a
  temperature, or two faces differing only in weight, go back to step 3.
- The project's rules beat this skill's defaults: a kiosk has one size,
  a light-only product has no dark variant, a firewalled customer gets
  no CDN font.
- A frozen token is not a checked token. Freezing says which colours
  exist, not that each passes where the screens use it.
- Real content from the flows or the product, word for word. Never lorem
  ipsum, never "Welcome to".
- One motion moment. A second animation is decoration; cut it.
- Never describe a screenshot that was not taken.
- File names `<n>-<name>` stay stable; the review cites them by name.
