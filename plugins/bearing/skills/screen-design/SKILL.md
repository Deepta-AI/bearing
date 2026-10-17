---
name: screen-design
description: 'Designs every screen in every state (empty, error, loading), desktop and phone, as clickable React or HTML mockups before code. Use when asked to "design the screens", "hi-fi mockups" or "show every state".'
argument-hint: "<feature> [--screens S-01,S-03] [--framework react-shadcn|react-native|flutter|compose|swiftui|web] [--round N] [--standalone]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git status:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 *skills/screen-design/scripts/states_check.py*), Bash(python3 *skills/screen-design/scripts/gallery_check.py*), Bash(python3 *skills/screen-design/scripts/bundle.py*), Bash(python3 *skills/design-system/scripts/system_page.py*), Bash(python3 *skills/design-critique/scripts/evidence.py*), Bash(python3 *skills/accessibility/scripts/contrast.py*), Bash(bash *bin/brg-kit-paths*)
---

# screen-design

A screen design is what the developer builds from and what a reviewer
clicks through to approve. It shows the product, not fragments: every
state drawn as the whole screen inside the app's chrome, the desktop
layout beside a 375 px arrangement designed for a phone, links that go
where the flows say, and a short note per state on what changed and why.
Most of the value is not in the drawing. It is in catching what the
signed-off documents got wrong before a developer builds it: a flows file
older than the PRD, a state the API can produce that nobody drew, a
requirement the API cannot support, a client comment that breaks an ADR
or the contrast floor. The doctrine in
`../design-directions/references/design-doctrine.md` governs visual
choices; read it before the first screen is planned.

Two paths. On React with shadcn/ui (the react-web template) the design is
code: each screen is a view composed from `src/components/ui` and the
tokens, every state rendered from fixtures in the gallery at `/__design`,
so nothing is translated later. On any other stack, or when the gallery
cannot run for the reviewer, it is the HTML design bundle: one page per
screen that opens from a file.

## Inputs

- Feature: `$1`; if absent, one question.
- Inventory, states, copy and navigation: the newest
  `docs/design/flows/<feature>/flows*.md`; else stories, code, or one
  question. `--screens` limits the set.
- Requirements: `docs/product/PRD.md` with its changelog; Accepted ADRs in
  `docs/adr/`; the API client and its types.
- Tokens, existing mockups, manifest, component contract, event sheet: each
  with its fallback. Detail: references/inputs.md
- Target: `--framework`; else the ui stack in `.bearing/state/autopilot.json`;
  else detected from the manifests. Only `react-shadcn` builds screens as
  code. Detail: references/targets-and-gates.md
- Gallery files (react-shadcn): `src/design/screen.ts`, `Gallery.tsx`,
  `registry.ts`. Detail: references/targets-and-gates.md
- Previous rounds: `docs/design/screens/<feature>/CHANGES.md` and
  `docs/design/feedback/`; `git log` on the mockup pages.
- Screenshots: `~/.claude/skills/gstack/browse/dist/browse` when
  executable; otherwise none are taken and the report says so.
- Templates: `templates/screen.html`, `templates/index.html`,
  `templates/gallery.html`, `templates/design.schema.json`,
  `templates/DESIGN-SYNC.md`, `templates/CHANGES.md`.
- Gates, Python 3 only: `scripts/gallery_check.py`, `scripts/states_check.py`,
  `scripts/bundle.py`, plus `evidence.py` and `contrast.py` from sibling
  skills. Detail: references/targets-and-gates.md
- `--standalone`: each page carries a copy of the tokens in
  `<style data-tokens>` instead of the link, for sending one file.

## Steps

### Reconcile the sources before the first screen

Print each finding; each one either becomes a designed state or a
concern (`ambiguity`, `missing-screen`, `undefined-state`, `dead-end`,
`risk`) raised for its owner. Zero screens and no brief: stop with
"provide flows, stories, code with screens, or a brief".

1. Eight checks: versions, precedence, states from the API contract, what
   the screen must know before the action, rules that combine, data as the
   product shows it, navigation, where the reviewer will open it.
   Detail: references/reconcile-sources.md

### Scope: design files only

- Write views, screen specs, mockup pages, the manifest and notes. Do not
  change library code, API clients, tests, a mockup generator or its
  template to make the design or a gate easier. A shared shell change
  adds the new navigation entry and nothing more. A helper the design
  wants (a formatter, a status mapper) is named as build work, not
  written.
- A repository's own mockup system is kept: extend its source, run its
  build. When a gate here cannot read that system, run the gate on a
  scratch copy or skip it and say so; never rewrite the system to fit
  the gate.
- No dependency is added; compose the existing components.

### react-shadcn (screens as code)

1. Per screen a presentational view in
   `src/features/<feature>/components/<Name>View.tsx`: props in, markup
   out, built only from `src/components/ui`. Then the shell, a
   `*.screen.tsx` per screen, responsive layouts, the gates and screenshots.
   Detail: references/react-shadcn.md

### HTML design bundle

1. When the repository already has mockups for the feature, extend them in
   their own format. Otherwise create or update `docs/design/design.json`.
   Then screen plan, tokens, one page per screen, self-review, the states
   gate, screenshots, the feature index and the manifest. Never edit the
   `audit` block by hand; never run `/design-sync` (the push to a shared
   design system is the person's). Detail: references/html-bundle.md

### A review round (client or team comments)

1. Find where the pages really come from; triage every comment before
   editing anything; measure colour changes; change only what the comments
   need; append the round to `CHANGES.md`. Detail: references/review-round.md

## Output contract

```
## Screen designs: <feature> (round <n>)
Target: react-shadcn (screens as code) | HTML bundle (<why>)   Open: <file to open, or command and URL>
Sources: flows <file> (against PRD v<x>) | PRD v<y> | ADRs <ids> | API <files>
Reconciled: <n> states added beyond the flows (<names>); gaps raised: <one line each, owner>
Screens: <gate counts line, verbatim>
Bundle: <bundle.py check counts line, verbatim> | not used (<reason>)
Contrast: <contrast.py counts line, verbatim> | no colour changed
Round: <per comment: verdict and reason> | first round
Ran: <each command with its result>
Not run: <build, typecheck, dev server, screenshots, each with its reason> | none
Next: design-critique docs/design/screens/<feature>
```

## Gotchas

- A known error code shown as "Something went wrong" is the most common
  gap in a design; the developer then ships exactly that.
- Designing around an API gap without saying so hands the developer a
  screen that cannot be built as drawn.
- A number, ratio or count in the report is one a script or a formatter
  printed; a screenshot or rendered result not produced is not described.
- On react-shadcn a raw `<table>`, `<button>` or `<input>` in a view is a
  hand-styled page; compose the component or extend it with a variant.
- The view takes props and the route wires data: the gallery state and
  the live page are one component.
- The annotation says what changed from the default and why, not the
  state's name again.
- The 375 px frame is designed on its own terms: its order, the primary
  action within reach, context cut to one line.
- Screens link one tokens file; a copied block drifts the first time the
  tokens change. `--standalone` is for sending one file.
- The state bar and annotations are prototype chrome; `#chrome=0` hides
  them and the review never scores them.
- Never invent an event name or a `data-component` name the contract
  lacks; list the gap instead.
- One motion moment per feature, behind the reduced-motion guard.
- Changing a shared shell, a formatter or a generator "while there" turns
  a design review into a code review nobody asked for.
