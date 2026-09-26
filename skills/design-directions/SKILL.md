---
name: design-directions
description: 'Produces three genuinely different visual design directions over the real screens, scores them and records the choice. Use when asked for "design directions", "three design options" or "which look should we go with".'
argument-hint: "<feature> [--screens S-01,S-03] [--round 2] [--unattended]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 -m http.server:*), Bash(python3 *skills/design-critique/scripts/evidence.py*)
---

# design-directions

Three variants exist so the user chooses between real alternatives, not
shades of one idea. The test is the swapped headline: if the headline of
one page could sit in another unnoticed, that pair failed. Each page is a
working artefact with real copy, both themes, three widths, visible focus
and one motion moment. `references/design-doctrine.md` governs every
choice and is read in full before the plan is written.

On the default stack, React with shadcn/ui and Tailwind, a direction is a
theme, not a page: `src/design/variants/<n>-<name>.css` overrides the
tokens under `[data-variant="<n>-<name>"]` (faces, type scale, colour
roles, radius, density, shadows, motion), and the design gallery renders
the real screens with `?variant=<n>-<name>`. Every direction is then
buildable by construction and the comparison is like for like: the same
screens, the same components, three looks. A direction the component set
cannot render is not a direction.

## Inputs

- Feature: looks in `$1`; if absent, asks one question.
- Screens and copy: looks in the newest `docs/design/flows/<feature>/flows*.md`
  (inventory, states, copy); if absent, `docs/product/backlog.md` stories
  for the feature; if absent, the routes and screens in the code; if
  absent, asks once for a one-paragraph brief. `--screens` limits the
  screens rendered; the default is the first screen of the happy path
  plus one state screen (empty or error).
- Design system: `DESIGN.md` or `docs/design/tokens.json`; when present
  the palette and the allowed faces are fixed, and variants differ in
  layout rhythm, type pairing within the allowed faces, and the motion
  moment. The output says which axes were frozen.
- Product world: README, `docs/product/PRD.md`, product copy; the
  subject's own materials, instruments and vernacular feed each brief.
- Previous round: `docs/design/variants/<feature>/approved.json`; with
  `--round 2` its chosen traits are fixed.
- Screenshots: the gstack browse binary
  `~/.claude/skills/gstack/browse/dist/browse` when executable; otherwise
  none are taken and the board says so.
- Evidence gate:
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py`
  (shoots and counts the widths and themes); Python 3 only.
- Templates: `templates/variant.html`, `templates/board.html` (HTML
  targets only).
- Target: the ui stack in the autopilot profile, else a React app or no UI
  code yet means `react-shadcn`, the default; any other stack uses the
  HTML variants.
- Reference looks: the statement or the user may name products whose feel
  the directions aim at (Stripe dashboard, Vercel/Geist, Linear); each
  direction states which trait it borrows and never copies a brand.
- `--unattended` (autopilot): no one chooses; step 9 scores the three with
  design-critique's checklist and takes the highest.

## Steps

1. Read the inputs; print each as read or absent. Zero screens and no
   brief: stop with "provide flows, stories, code with screens, or a brief".
2. Design plan: read `references/design-doctrine.md`. Write one paragraph
   per variant naming a direction from the directions list, the display
   and body faces, four to six colours in oklch or hex each with its
   reason, the layout rhythm in one sentence plus an ASCII wireframe, the
   signature element, the motion moment. Under a design system the colour
   and face lines cite the tokens.
3. Distinctness gate, before any HTML: compare every pair on display
   family, palette temperature and layout rhythm; all three must differ
   on all three axes (rhythm and pairing only, under a system). Then the
   swapped-headline test per pair. A failing pair: rewrite the weaker
   brief from a different row of the directions list and test again.
   Record the pairs judged distinct and the retries. This is a model
   judgement, not a measurement; the report says so.
4. Generic-default pass: for each brief, write the default answer to the
   same brief. Any line that matches it (the three AI looks, a stat and
   gradient hero, numbers on things that are not a sequence, Inter or
   Space Grotesk as display) is revised. Write what changed and why into
   the brief; the count goes in the output.
5. react-shadcn, instead of the HTML build: per direction write
   `src/design/variants/<n>-<name>.css` with every token override scoped
   under `[data-variant="<n>-<name>"]` (and its dark set under
   `[data-variant="<n>-<name>"].dark, [data-variant="<n>-<name>"][data-theme="dark"]`):
   `--font-sans` and `--font-mono` (one UI face and one mono; a display
   face only when the direction needs one, for headings), the type scale,
   the colour roles shadcn reads (`--background`, `--foreground`, `--card`,
   `--primary`, `--muted`, `--accent`, `--border`, `--ring`, `--sidebar-*`,
   `--chart-*`), `--radius`, density through the spacing it uses, shadows,
   and the motion easing. Fonts load from Google Fonts in `index.html`.
   The screens are the gallery's (`screen-design` first, or the
   template's sample screen and the flows' first screens). Screenshots:
   `evidence.py shoot --base http://127.0.0.1:<port>/__design/ ... '<id>?state=success&chrome=0&variant=<n>-<name>'`
   per direction, then `check`. Self-review as in step 7, then continue
   at step 9.
6. HTML targets. Build `<n>-<name>.html` per variant from `templates/variant.html`:
   tokens on `:root`, dark under `prefers-color-scheme` and
   `[data-theme="dark"]`, the screens as sections with the flows' copy
   including the state screen, no horizontal scroll at 375, 768, 1440, no
   half-width desktop column beside dead space, `:focus-visible` on every
   control, the motion moment in its slot behind the reduced-motion
   guard, the theme toggle as the only script, fonts from Google Fonts
   only, no other external resource. Copy the brief into the head comment.
7. Self-review each page against the hard rules and the anti-slop list
   in the doctrine; fix before showing; note each change.
8. Screenshots when browse is executable, all variants in one command:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base docs/design/variants/<feature> --out docs/design/variants/<feature>/shots <n>-<name>.html...`
   then the same with `check` in place of `shoot` (and no `--base`). It
   shoots 375, 768 and 1440 in light and dark, records console errors in
   `<n>-<name>.console.txt` (must be empty) and fails when a width is
   missing or dark did not apply. Read every PNG; fix overflow or
   collapse and re-shoot until `check` exits 0. Otherwise record
   `screenshots: not taken (browse absent)`.
9. Board `index.html` from `templates/board.html` (react-shadcn: a README with the gallery links per direction instead): one column per variant
   with the intent line, the `shots/<n>-<name>-1440.png` and
   `shots/<n>-<name>-375.png` images (iframes at those widths when there
   are no screenshots), rating 1 to 5, comment, remix field,
   chosen radio. The Copy button assembles JSON into a textarea; nothing
   is posted anywhere. Serve with
   `python3 -m http.server 0 --bind 127.0.0.1 --directory <folder>` and
   print the URL, or say to open the file.
10. Wait for the pasted JSON or typed feedback. Write `approved.json`
   (`round`, `date`, `chosen`, `ratings`, `comments`, `remix`, `notes`).
   Repeat the understanding back in one paragraph and wait for a yes.
   `--unattended`: score each direction with the ten categories of
   `../design-critique/references/review-checklist.md` over its
   screenshots, write `scores` (one number per direction), `chosen` (the
   highest), `chosen_by: "score"` and one line per direction on why it
   won or lost; the autopilot ux gate reads it. The user can overrule the
   choice at the merge request.
11. Round two on request: three new variants numbered 4 to 6 keeping the
    chosen traits (the remix spec, or the chosen variant's three axes) and
    varying the rest; steps 3 to 9 again; the board keeps round one below.
12. Print the output contract; name `design-critique` as next.

## Output contract

```
## Design variants: <feature> (round <n>)
Path: docs/design/variants/<feature>/
Screens rendered: N (from flows | stories | code | brief)
System: DESIGN.md | tokens.json (frozen: colour, faces) | none (world: <one line>)
Variants: 3
1-<name>: <display face> / <palette temperature> / <rhythm>
2-<name>: ...
3-<name>: ...
Distinctness: <d> of 3 pairs judged distinct (judged, not measured; retries: K)
Generic-default revisions: K (listed)
Focus: visible   Motion: 1, reduced-motion guarded
Screenshots: <evidence.py check counts line, verbatim>, console errors 0 | not taken (browse absent; widths and themes not verified)
Board: docs/design/variants/<feature>/index.html (http://127.0.0.1:<port>/ | open the file)
Approved: pending | <n>-<name> (ratings a/b/c, remix: <spec or none>) | <n>-<name> by score (scores a/b/c, unattended)
Next: design-critique docs/design/variants/<feature>
Alternates: /design-shotgun (gstack, OpenAI key, images), gsd-sketch (tabs in one file)
```

## Gotchas

- Three variants of one idea is one variant. When two palettes share a
  temperature or two display faces share a class, one goes back to step 2.
- A design system freezes colour and faces, not rhythm, pairing or
  motion; the swapped-headline test still runs on those.
- Real content from the flows or the product. When a state has no copy,
  write it and mark it `proposed` so `ux-flows` can absorb it. Never
  lorem ipsum, never "Welcome to".
- One motion moment. A second animation is decoration; cut it.
- The board writes nothing. The pasted JSON is the record; `approved.json`
  is the artefact the next skills read.
- Never describe a screenshot that was not taken.
- File names `<n>-<name>.html` stay stable; the review cites them by name.
