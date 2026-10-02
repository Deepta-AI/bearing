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
  `docs/design/flows/<feature>/flows*.md` (sections 1, 2, 4 and 7); if
  absent, the stories in `docs/product/backlog.md` or
  `docs/product/PRD.md` (navigation proposed and raised as `ambiguity`);
  if absent, the routes and screens in the code; if absent, one question
  for a one-paragraph brief. `--screens` limits the set.
- Requirements: `docs/product/PRD.md` with its version and changelog;
  Accepted ADRs in `docs/adr/`; the API client and its types (statuses,
  error codes, fields) for every call a screen makes.
- Tokens: the file an ADR or README names as the source of colour (on
  react-shadcn usually `src/index.css`); else `docs/design/tokens.css`;
  else generated from `docs/design/tokens.json` with `system_page.py
  tokens-css`; else written by hand from the approved variant, else
  `DESIGN.md`, else the brief, headed `proposed`.
- Existing mockups: pages already under `docs/design/screens/<feature>/`
  and how they are made (a build script, a JSON source, a template, a
  README note). A repository's own mockup system is used as it is.
- Manifest: `docs/design/design.json` (`templates/design.schema.json`),
  for a new HTML bundle or one already using it.
- Component contract: `docs/design/components.md`; if absent,
  `data-component` names come from the region's role and the index says
  `no contract`.
- Event sheet: `docs/analytics/EVENT_SHEET.md`; if absent, no
  `data-event` attributes and the index says `no sheet`.
- Target: `--framework`; else the ui stack in
  `.bearing/state/autopilot.json`; else detected: `react-native` or `expo`
  in package.json is `react-native`; `pubspec.yaml` with a `flutter:`
  dependency is `flutter`; `androidx.compose` in a gradle file is
  `compose`; `Package.swift` or an `.xcodeproj` is `swiftui`; a React web
  app, or no UI code yet, is `react-shadcn`. Only `react-shadcn` builds
  screens as code, and only when the gallery can run (step 8 of the
  reconciliation below); every other target builds the HTML bundle.
- Gallery files (react-shadcn): `src/design/screen.ts`, `Gallery.tsx`,
  `registry.ts`; absent in an older app: copy them from
  `templates/skeleton/src/design/` in the `bearing-apps:react` skill
  (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths" --skill react` prints
  its directory, or names the plugin to install) and say so; when that
  plugin is absent, use the HTML bundle.
- Previous rounds: `docs/design/screens/<feature>/CHANGES.md` and
  `docs/design/feedback/`; `git log` on the mockup pages.
- Screenshots: `~/.claude/skills/gstack/browse/dist/browse` when
  executable; otherwise none are taken and the report says so.
- Templates: `templates/screen.html`, `templates/index.html`,
  `templates/gallery.html`, `templates/design.schema.json`,
  `templates/DESIGN-SYNC.md`, `templates/CHANGES.md`.
- Gates, Python 3 only: `scripts/gallery_check.py` (react-shadcn: every
  inventory screen has a `*.screen.tsx`, every state is a key of its
  `states`, no raw element where a component exists);
  `scripts/states_check.py` (HTML: every inventory state has a panel and a
  control that reaches it, no unfilled placeholder; reads a repo's own
  `data-target` or `#state=` links and treats `no slots` as `no-slots`);
  `scripts/bundle.py` (manifest audit, gallery, check);
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py`
  (widths and themes);
  `${CLAUDE_PLUGIN_ROOT}/skills/accessibility/scripts/contrast.py`
  (measured WCAG ratios).
- `--standalone`: each page carries a copy of the tokens in
  `<style data-tokens>` instead of the link, for sending one file.

## Steps

### Reconcile the sources before the first screen

Print each finding; each one either becomes a designed state or a
concern (`ambiguity`, `missing-screen`, `undefined-state`, `dead-end`,
`risk`) raised for its owner. Zero screens and no brief: stop with
"provide flows, stories, code with screens, or a brief".

1. Versions. The flows usually say which PRD version or date they were
   written against. When the PRD is newer, read its changelog and every
   requirement added or changed since; each that implies a state, a rule
   or a screen is designed now and raised as `undefined-state` for
   whoever owns the flows. Signed off does not mean complete.
2. Precedence: an Accepted ADR, then the PRD, then the flows, then older
   design notes. A design doc an ADR retired (an old palette, an old
   layout rule) is never copied from, even when it is the more readable
   file.
3. States come from the contract as well as the flows table. For each
   screen, list every status in the API's lifecycle it can display and
   every error code its calls return (a 409 conflict, a 403 permission
   or limit, a 422 validation). Each gets a state or a message that says
   what happened and what to do; a generic error for a known code is a
   miss. A requirement with no row in the flows (a confirmation, a
   second step) gets its state too.
4. What the screen must know before the action. When a requirement says
   the person is "not offered" an action that would fail, but the API
   only reveals the condition as an error from that action, the UI
   cannot know it up front: that is an API gap. Design the state as if
   the data existed, label the assumption on the state, raise it, and
   never describe the missing field as existing.
5. Rules that combine. Read the requirements that touch the same object
   together (a threshold and a limit, a role and a count, two approvers
   and one person who holds a limit) and check that every combination
   can be satisfied. An impossible or undefined combination is raised
   as a question, not settled silently by the design.
6. Data as the product shows it. Values go through the repository's own
   formatter (money in minor units, locale digit grouping, the time zone
   its date formatter uses), and every fixture value is computed by that
   rule, not typed by eye. Thresholds keep their boundary as written
   ("or more" includes the boundary value). Lists are ordered as the
   requirement says, not in fixture-file order.
7. Navigation. An edge to a screen that is out of scope or not designed
   is plain text in the design plus a `missing-screen` concern, never a
   link or a route.
8. Where the reviewer will open it. The react-shadcn gallery is the
   deliverable only when it can run for that reviewer: dependencies are
   installed (or may be installed) and someone will serve it. Otherwise
   build the HTML bundle, which opens from a file, with the app's token
   values copied into it and their source named in a comment; say that
   views in the app follow once the dependencies install.

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
   out, no fetching, built only from `src/components/ui` and layout
   utilities on the spacing scale; colours by role (`bg-card`,
   `text-muted-foreground`), never a literal; the type scale the tokens
   set; a `Skeleton` loading layout that holds the success layout's
   shape.
2. The shell once for every screen, following the flows' navigation map,
   with the feature's entry marked current. Change only the entry list
   of an existing shell.
3. Per screen `src/features/<feature>/screens/<id>-<name>.screen.tsx`
   exporting `screen: ScreenSpec` (`id`, `name`, `feature`, `job`,
   `states`), one entry per state from the reconciliation, rendering the
   view with fixtures in the flows' copy. Fixtures use invented companies
   and people on reserved domains (`example.com`, `example.in`).
4. Responsive by design: at 375 the table becomes a card list or scrolls
   inside its own container with the key columns readable, two columns
   stack, the primary action stays reachable without horizontal scroll;
   at 1440 no half-width column beside dead space.
5. Gates: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/gallery_check.py" --src <src> --flows <flows file>`
   until it exits 0; then the repository's own checks that exist (`make
   check`, `make design-lint`). A target that does not exist, or a build
   that needs `node_modules` that are absent, is reported as not run.
6. Screenshots from the running gallery when it runs
   (`<id>?state=<name>&chrome=0`):
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base http://localhost:<port>/__design/ --out docs/design/screens/shots <id>?state=<state>&chrome=0...`
   then `check`. `docs/design/screens/README.md` lists the screens,
   states and the gallery URL.

### HTML design bundle

1. When the repository already has mockups for the feature, extend them
   in their own format and skip the manifest steps (9). Otherwise create
   or update `docs/design/design.json` against the schema: `brief`,
   `directions`, `stories`, a `sitemap` with a leaf per screen keyed
   `<feature>/S-nn`, and a `navigation` generated from the flows'
   section 4 maps (top-level destinations; three to five on the phone tab
   bar; `why`; `source`).
2. Screen plan, one block per screen: its single job, the regions with
   `data-component` names, the states from the reconciliation, the copy
   per state, controls in tab order with event names, the links out (one
   per navigation edge), the current item in the chrome, and the 375 px
   arrangement: what moves, what docks, what drops to one line. A phone
   layout that only stacks the desktop columns is not an arrangement.
   Write the generic default answer next to each block; revise every line
   that matches it.
3. Tokens: link the one tokens file; no page declares a colour. When
   `docs/design/tokens.css` is absent and `tokens.json` exists:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" tokens-css --tokens docs/design/tokens.json --out docs/design/tokens.css`.
4. Build `<id>-<name>.html` per screen from `templates/screen.html`: the
   tokens link (or the `data-tokens` copy with `--standalone`), a state
   bar, one `[data-state]` panel per state, each the whole screen: an
   annotation (`data-annotation`), a desktop and a phone frame
   (`data-frame`), each in its app chrome (`data-app-chrome`; `none:
   <reason>` only for a screen with no chrome by design) with
   `aria-current` on the current item. `#state=<name>`, `#state=all` and
   `#chrome=0` deep links; a skip link, `:focus-visible` on every control,
   44 px targets, labels bound by `for`, `data-event` only for names the
   sheet has; fonts from Google Fonts only, no other external resource.
5. Self-review before anything is shown: the three things the eye lands
   on are the screen's job; every button is a verb and its object; every
   error says what happened and what to do; the phone frame is arranged,
   not squeezed. Fix and count the findings.
6. States gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/states_check.py" --screens docs/design/screens/<feature> --flows <flows file>`
   (drop `--flows` when the inventory came from stories, code or a
   brief; a state the screen truly lacks is marked `<!-- n/a: <state>
   because <reason> -->`). States the reconciliation added beyond the
   flows are checked by reading, and listed.
7. Screenshots when browse is executable:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base docs/design/screens/<feature> --out docs/design/screens/<feature>/shots '<id>-<name>.html#chrome=0'...`
   then `check`. Read every PNG; fix overflow or collapse and re-shoot.
8. Feature index `docs/design/screens/<feature>/index.html` from
   `templates/index.html`: per screen the job, a link per state, the
   screenshots (iframes when none) and the redlines (spacing, type roles,
   token names, component names, events).
9. Manifest only: add the concerns, then
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" audit --design docs/design`,
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" gallery --design docs/design`,
   `docs/design/DESIGN-SYNC.md` from its template, and
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" check --design docs/design`
   until it exits 0. Never edit the `audit` block by hand; never run
   `/design-sync` (the push to a shared design system is the person's).

### A review round (client or team comments)

1. Find where the pages really come from. When they are generated (a
   build script, a JSON source), rebuild with the repository's command
   and `git diff` the pages: a line the rebuild changes is a hand edit
   made to the output (`git log` on the page names who and why). Port
   every such edit into the source first and rebuild until the diff is
   empty. From then on edit the source and rebuild; an edit to a
   generated page is lost at the next rebuild.
2. Triage every comment before editing anything, against the PRD's scope,
   the Accepted ADRs, the flows, what the code does (does the state the
   client wants dropped actually occur, and for which inputs) and the
   accessibility floor. Each gets a verdict: applied, applied with a
   change, or not applied, with the reason and, when not applied, the
   question back. A comment about a screen that does not exist: say so,
   name the designed screen it most plausibly means from what it
   describes, and ask; never invent the screen.
3. Colour changes are measured, not eyeballed. Find every use of the
   token, including tokens that alias it (`--color-focus:
   var(--color-primary)`, borders, link text), and measure each rendered
   pair with
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/accessibility/scripts/contrast.py" FG:BG[:MIN]...`:
   text 4.5:1 (3:1 at 24 px, or 18.66 px bold), focus rings and control
   boundaries 3:1 against the colour next to them. Keep the requested
   colour where it can pass and fix its partner (dark text on a light
   brand green; the focus token on its own darker value); state the
   ratios in the reply.
4. When rewording a state that stays, keep its facts (every cause the
   code has for it). A mockup change the app does not do yet (a time
   format, a new control) is named as build work with the file that would
   change.
5. Change only what the comments need. After the rebuild, pages no
   comment touches are byte-identical.
6. Append the round to `CHANGES.md` (comment, verdict, change,
   `file:line`), rerun the gates, re-shoot touched screens when browse is
   executable. Stop when the user says done, or after three rounds with no
   new comment.

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
