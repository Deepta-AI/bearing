---
name: design-directions
description: 'Produces the visual direction over the real screens (one impeccable pick, else three variants) and records the choice. Use when asked for "design directions", "three design options" or "which look should we go with".'
argument-hint: "<feature> [--screens S-01,S-03] [--round 2] [--unattended]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE), Bash(bash *bin/brg-config*), Bash(readlink DESIGN.md), Bash(rm DESIGN.md), Bash(ln -s docs/design/DESIGN.md DESIGN.md), Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 -m http.server:*), Bash(python3 *skills/design-critique/scripts/evidence.py*), Bash(python3 *skills/design-critique/scripts/pairs.py*)
---

# design-directions

With impeccable installed and attended, its round picks one direction and
Bearing renders and measures it. Otherwise three variants give the user real
alternatives, not shades of one idea. The test is the swapped headline: if
the headline of one page could sit in another unnoticed, that pair failed.
Each page is a working artefact with real copy, visible focus and one motion
moment, built inside the project's own rules. `references/design-doctrine.md`
governs the fallback's choices and is read in full before its plan is written.

A direction is judged by the people who use the screen, not by its name. Every
direction says which user and which condition it serves first and where it is
weakest for the others. Detail: references/constraints-and-checks.md

## Inputs

- Feature: looks in `$1`; if absent, asks one question.
- Screens and copy: the newest `docs/design/flows/<feature>/flows*.md`
  (inventory, states, copy, privacy and timing rules); if absent,
  `docs/product/backlog.md` stories; if absent, the routes and screens in the
  code; if absent, asks once for a one-paragraph brief. `--screens` limits the
  screens; the default is the happy path's first screen plus one state screen
  (empty, delayed or error).
- Users: README, `docs/product/PRD.md`, product copy: who uses the screen, on
  what device, where, for how long.
- Project constraints, which override every default in this skill: accepted
  ADRs under `docs/adr/`, the Content-Security-Policy, the README's hardware
  and deployment notes, brand notes (where fonts may come from, a fixed device
  size, light only, a contrast floor, a touch-target floor, a motion limit,
  privacy rules). A brand note never outranks an Accepted ADR. Detail: references/constraints-and-checks.md
- Design system: `DESIGN.md`, `docs/design/tokens.json`, the token CSS file.
  When they disagree, the newest Accepted ADR and the file the code loads win,
  and the stale document is named in the output. A system freezes colour and
  faces; variants then differ in layout, hierarchy, type scale within the
  allowed faces, density and the motion moment.
- Previous round: `docs/design/variants/<feature>/approved.json`; with
  `--round 2` its chosen traits are fixed.
- Screenshots: the gstack browse binary
  `~/.claude/skills/gstack/browse/dist/browse` when executable, or a local
  headless Chrome; otherwise none are taken and the output says so.
- Measurement:
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py` (shots at
  375, 768, 1440 in light and dark) and
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py` (contrast of
  every text pair in static pages); Python 3 only.
- Templates: `templates/variant.html`, `templates/board.html` (HTML only).
- Target: the ui stack in the autopilot profile, else a React app with
  `components.json` or no UI code yet means react-shadcn; any other stack uses
  the HTML variants.
- Reference looks the user names (Stripe dashboard, Linear): each direction
  states which trait it borrows and never copies a brand.
- `--unattended` (autopilot): no one chooses; step 10 scores the three.
- Impeccable: `${CLAUDE_PLUGIN_ROOT}/references/impeccable.md` (Detect,
  Unattended, its `## design-directions` round); `PRODUCT.md` when present.

## Steps

1. Read the inputs; print each as read or absent, then list the constraints
   found with their source. They replace the defaults: the device size for
   widths 375, 768 and 1440, one theme for two when a rule says so, stricter
   project numbers for 44 px, 4.5:1 and 200 to 700 ms motion. Zero screens and
   no brief: stop with "provide flows, stories, code with screens, or a brief".
   Detail: references/constraints-and-checks.md
   Then the path, as the impeccable reference's design-directions section says.
2. Audit what the directions will sit on, before designing; each finding goes
   in the output, even when it is outside the feature: colours outside the
   tokens (Grep the screens and components for fixed palette classes, hex,
   `rgb(` and `oklch(` literals and inline `style=`), text tokens against the
   project's contrast rule on every surface they can sit on (a token that
   fails is not used for that role; name it), field edges and control
   boundaries at 3:1 (WCAG 1.4.11), target sizes as rendered, fonts named but
   never loaded, and privacy (what the flows forbid). Detail: references/audit.md
3. Design plan: read `references/design-doctrine.md`. One paragraph per
   variant: the direction row, the user and condition it serves first and its
   weak spot, the faces (only faces the constraints allow), four to six colours
   in oklch or hex each with its reason, the layout rhythm in one sentence plus
   an ASCII wireframe, the signature element, the motion moment. Under a design
   system the colour and face lines cite the tokens, and the output says which
   axes were frozen.
4. Distinctness gate, before any code: every pair differs on display family,
   palette temperature and layout rhythm (under a system: layout, hierarchy and
   type scale). Then the swapped-headline test per pair. A failing pair:
   rewrite the weaker brief from another row and test again. This is a
   judgement, not a measurement; the output says so.
5. Generic-default pass: write the default answer to the same brief. A plan
   line that matches it (the three AI looks, a stat-and-gradient hero, Inter or
   Space Grotesk as display) is revised; the count goes in the output.
6. react-shadcn build (instead of step 7): a direction is a theme the real
   screens render with; one the component set cannot render is not a
   direction. One `src/design/variants/<n>-<name>.css` per direction,
   overriding the fonts, type scale and colour roles shadcn reads, scoped to
   `:root[data-variant="<n>-<name>"]` on the element that carries the app's
   dark class, dark on that same element (dark under
   `@media (prefers-color-scheme)` alone is wrong when the app stores the
   user's choice). `:root`, `.dark` and the default look untouched; nothing
   applies without the switch: the design gallery, else a dev-only
   `?variant=` behind `import.meta.env.DEV`; print how to view each. Step 2's
   colours move onto variables with the old values as defaults, or are
   listed. Density and shape through variables or `data-slot`/`data-part`,
   never per-direction classes or conditionals in components; a direction
   adds no content, fields, computed values or controls; 44 px (or the
   project's floor) with phone users. Fonts: bundled faces, Fontsource
   packages or self-hosted files, never a third-party host when the CSP or
   an ADR forbids it; the CSP never loosened; packages not installed said
   so; a face with no self-hostable source dropped with the reason. Then
   step 8, and continue at step 9. Detail: references/react-shadcn-build.md
7. HTML targets. Build `<n>-<name>.html` per variant from
   `templates/variant.html`: tokens on `:root`, the screens as sections with
   the flows' copy word for word including the state screen, at the project's
   sizes (the device size and orientation when fixed; else no horizontal scroll
   at 375, 768 and 1440 and no half-width desktop column beside dead space),
   dark only when the product has dark, `:focus-visible` on every control, the
   motion moment behind the reduced-motion guard and inside the project's limit,
   the theme toggle as the only script. Fonts load the way the product can load
   them (a Google Fonts link only when no constraint forbids it); sample data
   follows the flows' privacy rules, and a sensitive input shows no typed value
   in plain view; copy not in the flows is marked `proposed`. Detail: references/html-build.md
8. Check each direction and fix before showing; record each fix:
   - Contrast, computed from the values written, in every theme the product
     has, against the project's ratios. HTML pages:
     `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py" --need <body ratio> <n>-<name>.html...`
     (its large-text threshold is 3:1; apply a stricter project rule by
     hand). react-shadcn: compute every text pair per direction and theme.
     Print the count; zero pairs checked is a failure, not a pass. Detail: references/constraints-and-checks.md
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
    direction instead): one column per variant with the user it serves, the
    shots or iframes at the product's size, rating 1 to 5, comment, remix
    field, chosen radio. The board chrome stays neutral, loads nothing from
    another host and posts nothing. Serve it with
    `python3 -m http.server 0 --bind 127.0.0.1 --directory <folder>` only when
    someone will open it now; else say to open the file. Record `approved.json`
    (`round`, `date`, `source`: `bearing`, `recommended`, `chosen`, `ratings`,
    `comments`, `remix`, `notes`). Impeccable round: one column, no chosen
    radio; `source`, `chosen`, `challengers`, `direction` are already written,
    this step fills `evidence`. `chosen` stays null until the user picks: a
    recommendation goes in `recommended`, never in `chosen`, and no direction
    becomes the default.
    When feedback arrives, repeat it back in one paragraph before writing it.
    `--unattended`: score each direction with the ten categories of
    `../design-critique/references/review-checklist.md`, write `scores`,
    `chosen` (the highest), `chosen_by: "score"` and one line per direction on
    why it won or lost; the user can overrule it at the merge request.
11. Round two on request (the impeccable round: as its reference says):
    variants 4 to 6 keep the chosen traits (the remix spec, or the chosen
    variant's axes) and vary the rest; steps 4 to 10 again; the board keeps
    round one below.
12. Print the output contract; name `design-critique` as next.

## Output contract

```
## Design variants: <feature> (round <n>)
Folder: docs/design/variants/<feature>/ (and src/design/variants/ on react-shadcn)
Path: impeccable (one round; picked <name> over <challengers>) | fallback: three variants (impeccable not installed | unattended: Bearing's doctrine)
Impeccable: <commands run>; inferred: <facts> | none
Screens rendered: N (from flows | stories | code | brief)
Constraints: <each, with its source> | none found
System: <source followed> (frozen: colour, faces; stale: <doc> | none) | none
1-<name>: serves <user, condition>; <face> / <temperature> / <rhythm>
2-<name>: ... (2 and 3 on the fallback only)
3-<name>: ...
Distinctness: <d> of 3 pairs judged distinct (judged, not measured; retries: K) | n/a (impeccable round)
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
- A frozen token is not a checked token. Freezing says which colours
  exist, not that each passes where the screens use it.
- Real content from the flows or the product, word for word. Never lorem
  ipsum, never "Welcome to".
- One motion moment. A second animation is decoration; cut it.
- Never describe a screenshot that was not taken.
- File names `<n>-<name>` stay stable; the review cites them by name.
