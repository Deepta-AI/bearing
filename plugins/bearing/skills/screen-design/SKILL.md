---
name: screen-design
description: 'Designs every screen in every state, desktop and phone: React and shadcn screens in the app''s design gallery, or HTML mockups. Use when asked to "design the screens", "hi-fi mockups" or "show every state".'
argument-hint: "<feature> [--screens S-01,S-03] [--framework react-shadcn|react-native|compose|swiftui|web] [--round N] [--standalone]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(test:*), Bash(make:*), Bash(~/.claude/skills/gstack/browse/dist/browse:*), Bash(python3 *skills/screen-design/scripts/states_check.py*), Bash(python3 *skills/screen-design/scripts/gallery_check.py*), Bash(python3 *skills/screen-design/scripts/bundle.py*), Bash(python3 *skills/design-system/scripts/system_page.py*), Bash(python3 *skills/design-critique/scripts/evidence.py*), Bash(bash *bin/brg-kit-paths*)
---

# screen-design

On the default stack, React with shadcn/ui and Tailwind (react-web
template), the design is code: each screen is a component in the app,
assembled from `src/components/ui` and the tokens, with every state
rendered from fixtures in the design gallery at `/__design`, which is
also what a client clicks through. Nothing is translated afterwards, so
every screen shares one component set, one type scale and one set of
tokens by construction; screens drawn as separate HTML and translated
by hand come out basic and unlike each other. The
HTML design bundle below is the path for a stack the implementer chose
instead.

A screen design is the artefact the developer builds from and the thing a
client clicks through to approve, so it shows the product, not a
fragment: every state drawn as the whole screen inside the app's chrome,
with a short note on what changed and why, the desktop layout beside a
375 px arrangement designed for a phone, and links that go to the screen
the flows say they go to. One manifest, `docs/design/design.json`, holds
the brief, the directions, the sitemap, the navigation and its reason,
every screen and what was raised while designing; a gallery and an
audit are generated from it. Every screen links the one `tokens.css`.
The doctrine in `../design-directions/references/design-doctrine.md`
governs every choice; it is read in full before the first screen is
planned.

## Inputs

- Feature: looks in `$1`; if absent, asks one question.
- Screen inventory, states, copy and navigation: the newest
  `docs/design/flows/<feature>/flows*.md` (sections 1, 2, 4 and 7); if
  absent, screens from `docs/product/backlog.md` stories or
  `docs/product/PRD.md`, and the navigation is proposed and listed as an
  `ambiguity` concern; if absent, from the routes, screens and page
  components in the code; if absent, asks once for a one-paragraph
  brief. `--screens` limits the set; the default is every screen.
- Manifest: `docs/design/design.json`, shaped by
  `templates/design.schema.json`, read and updated in place (other
  features' screens are kept); if absent, created in step 2.
- Tokens: `docs/design/tokens.css`, the shared file every page links;
  if absent and `docs/design/tokens.json` exists, generated with
  `system_page.py tokens-css` from design-system; if both are
  absent, written by hand in the same `--color-<role>` names from the
  `:root` block of `docs/design/variants/<feature>/approved.json`, else
  `DESIGN.md`, else one paragraph from the user, and headed `proposed`.
- Component contract: `docs/design/components.md`; if absent,
  `data-component` names come from the region's role (list, form,
  dialog, toast) and the index says `no contract`.
- Target: `--framework`; if absent, the ui stack in the autopilot profile
  (`.bearing/state/autopilot.json`); if absent, detected: `react-native` or
  `expo` in package.json is `react-native`; `androidx.compose` in a gradle
  file is `compose`; `Package.swift` or an `.xcodeproj` is `swiftui`; a
  React app, or no UI code yet, is `react-shadcn`, the default. Only
  `react-shadcn` builds screens as code; every other target builds the
  HTML design bundle.
- Design gallery (react-shadcn): `src/design/screen.ts`, `Gallery.tsx`
  and `registry.ts` from the react-web template (`web/src/...` when the
  app lives in `web/`); absent in an older app: copy them from
  `templates/skeleton/src/design/` in the `bearing-apps:react` skill
  (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths" --skill react` prints
  its directory, or names the plugin to install) with the two gallery routes in `routes.tsx`, and say so. The component
  inventory is `src/components/ui` (32 shadcn components in the template).
- Event sheet: `docs/analytics/EVENT_SHEET.md`; if absent, no
  `data-event` attributes are written and the index says `no sheet`.
- Motion moment: the storyboard's "design answers with" column or the
  chosen variant's moment; if absent, the slot stays empty.
- Screenshots: `~/.claude/skills/gstack/browse/dist/browse` when
  executable; otherwise none are taken and the index says so.
- Previous rounds: `docs/design/screens/<feature>/CHANGES.md`; if
  absent, this is round 1.
- Templates: `templates/screen.html`, `templates/index.html`,
  `templates/gallery.html`, `templates/design.schema.json`,
  `templates/DESIGN-SYNC.md`, `templates/CHANGES.md`.
- Gates, Python 3 only: `scripts/gallery_check.py` (react-shadcn: every
  inventory screen has a `*.screen.tsx`, every state is a key of its
  `states`, no raw element where a component exists),
  `scripts/states_check.py` (HTML: every inventory state has a reachable
  panel, no unfilled placeholder), `scripts/bundle.py`
  (chrome, annotations, links, navigation edges, tokens, stories and a
  real audit in design.json) and
  `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py`
  (widths and themes). When ux-flows is absent from the plugin,
  bundle.py prints "flows checks skipped" and counts 0 flows files.
- `--standalone`: each screen carries a copy of tokens.css in
  `<style data-tokens>` instead of the link, for sending one file on its
  own; if absent, the link.

## Steps

### react-shadcn (the default)

1. Read the inputs; print each as read or absent. Zero screens and no
   brief: stop with "provide flows, stories, code with screens, or a brief".
2. Per screen, a presentational view in
   `src/features/<feature>/components/<Name>View.tsx`: props in, markup
   out, no data fetching, built only from `src/components/ui` (Sidebar,
   Table, Tabs, Card, Dialog, Sheet, DropdownMenu, Select, Command,
   Tooltip, Skeleton, Progress, Badge, Breadcrumb, the form controls) and
   layout utilities on the spacing scale; colours by role (`bg-card`,
   `text-muted-foreground`), never a literal; one type scale (`text-xs` to
   `text-2xl` as the tokens set them); a `Skeleton` layout for loading
   that holds the success layout's shape; the motion moment from
   `docs/design/motion.md` through `tw-animate-css` classes
   (`animate-in fade-in slide-in-from-bottom-2`), never a second one.
3. The shell once, for every screen: `SidebarProvider` with the app
   sidebar and a header with the breadcrumb, collapsing to a `Sheet`
   below `md` (the sidebar component does this with `useIsMobile`); the
   navigation follows the flows' section 4 map.
4. Per screen, `src/features/<feature>/screens/<id>-<name>.screen.tsx`
   exporting `screen: ScreenSpec` (`id`, `name`, `feature`, `job`,
   `states`), one entry per inventory state rendering the view with
   fixtures in the flows' copy. Fixtures use invented companies and
   people on reserved domains (`example.com`, `example.in`), never a
   real brand or person.
5. Responsive by design, not by shrinking: at 375 the table becomes a
   card list or scrolls in its own container, two columns stack, the
   primary action stays in reach; at 1440 no half-width column beside
   dead space.
6. Gate: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/gallery_check.py" --src <src> --flows <newest flows file per feature>...`
   until it exits 0, then `make check` (lint, typecheck, tests) and
   `make design-lint`.
7. Screenshots from the running gallery (`make dev`; the pages are
   `<id>?state=<name>&chrome=0`):
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base http://127.0.0.1:<port>/__design/ --out docs/design/screens/shots <id>?state=<state>&chrome=0...`
   then `check`. `docs/design/screens/README.md` lists the screens, their
   states and the gallery URL; the gallery is the index a reviewer opens.
8. The feedback loop and the output contract as in steps 11 and 12 of the
   HTML bundle below, with the gallery as the thing reviewed.

### HTML design bundle (another stack)

1. Read the inputs; print each as read or absent. Zero screens and no
   brief: stop with "provide flows, stories, code with screens, or a brief".
2. Manifest. Create or update `docs/design/design.json` against the
   schema: `brief` (surface, audience by role, must feel, avoid) from
   DESIGN.md, the PRD or the brief; `directions` from the variants, the
   approved one `chosen: true`, each losing one with its reason;
   `stories` from the backlog ids this feature carries. The `sitemap` is
   a tree with one section per feature and a leaf per inventory screen,
   keyed `<feature>/S-nn`. The `navigation` is generated from every
   flows file's section 4 map: the screens entered from a nav route or
   with no parent are the top-level destinations; three to five become
   the mobile bottom tab bar and the desktop side nav holds them all;
   `why` says how deep the product is and how often each destination is
   used; `source` names the flows files. A destination that no flows
   file designs is kept out of the chrome and raised as a
   `missing-screen` concern.
3. Screen plan, one block per screen: its single job, platform (`web`,
   `mobile` or `both`), the regions with their `data-component` names,
   the states (the five, plus the screen's own from the flows table; an
   `n/a` cell stays out with its reason), the copy per state, the
   controls in tab order with their event names, and where the motion
   moment lands (one screen). Then three lines no screen skips: the
   links out, one per navigation-map edge from this screen, each to the
   target's file; the current item in the chrome; and the 375 px
   arrangement, saying what moves, what docks above the tab bar and
   what drops to one line. A phone layout that only stacks the desktop
   columns is not an arrangement.
4. Generic-default pass per screen: write the default answer to the
   same plan. Every matching line is revised and the change is noted.
5. Tokens. When `docs/design/tokens.css` is absent and `tokens.json`
   exists:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-system/scripts/system_page.py" tokens-css --tokens docs/design/tokens.json --out docs/design/tokens.css`.
   Otherwise write it by hand as Inputs says. Record the source and any
   role the source lacked. No screen declares a colour.
6. Build `<id>-<name>.html` per screen from `templates/screen.html`: the
   `../../tokens.css` link (or the `data-tokens` copy with
   `--standalone`), the state bar with an All states button, and one
   `[data-state]` panel per state. Each panel is the whole screen: an
   annotation (`data-annotation`, one or two sentences on what changed
   from the default and why), a desktop frame and a mobile frame
   (`data-frame`), each holding its app chrome (`data-app-chrome`: the
   top bar and side nav on desktop, the top bar and bottom tab bar on
   the phone; `none: <reason>` only for a screen with no chrome by
   design, such as a full-screen camera). The chrome's links go to the
   designed screens' files with `aria-current` on the current one. Then
   the flows' copy per state, `#state=<name>`, `#state=all` and
   `#chrome=0` deep links, three layouts with no horizontal scroll and
   no dead half column at 1440, a skip link, `:focus-visible` on every
   control, 44 px targets, labels bound by `for`, `data-component` on
   every region and control, `data-event` on controls the sheet names,
   the motion moment in its slot behind the reduced-motion guard, fonts
   from Google Fonts only, no other external resource. The only script
   is the state, screenshot and theme switcher.
7. Self-review, two passes, before anything is shown. First the
   generic-default check from step 4 against the built page. Then the
   screen-level checks: the three things the eye lands on are the
   screen's job; every inventory state has a panel; every button is a
   verb plus its object and every error says what happened and what to
   do; the phone frame is arranged, not squeezed; no hit on the
   anti-slop list. Fix each finding; count them. Then the states gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/states_check.py" --screens docs/design/screens/<feature> --flows <flows file>`
   (drop `--flows` when the inventory came from stories, code or a brief;
   the baseline five then apply, and a state the screen truly lacks is
   marked `<!-- n/a: <state> because <reason> -->` in the page). Fix what
   it reports and rerun until it exits 0.
8. Screenshots when browse is executable, all screens in one command:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/evidence.py" shoot --base docs/design/screens/<feature> --out docs/design/screens/<feature>/shots '<id>-<name>.html#chrome=0'...`
   then the same with `check` in place of `shoot` (and no `--base`). It
   shoots 375, 768 and 1440 in light and dark (`#chrome=0` shows the
   phone frame below 720 px and the desktop frame above), records
   console errors in `<id>-<name>.console.txt` (must be empty) and fails
   when a width is missing or dark did not apply. Read every PNG; fix
   overflow or collapse and re-shoot.
9. Feature index `docs/design/screens/<feature>/index.html` from
   `templates/index.html`: per screen the job, a link per state, the
   three screenshots (iframes when none), and the redlines: spacing
   values used, type roles, token names, component names, events.
10. Bundle. Add what was raised while designing to `concerns`, each
    typed `ambiguity`, `missing-screen`, `undefined-state`, `dead-end` or
    `risk`, with the screen key and, for a story no screen serves, the
    story id in the detail. Then run the audit, which counts from the
    files and writes the numbers into design.json:
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" audit --design docs/design`.
    Fix every finding and rerun until it exits 0; never edit the
    `audit` block by hand. Render the gallery:
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" gallery --design docs/design`.
    Write `docs/design/DESIGN-SYNC.md` from `templates/DESIGN-SYNC.md`
    with this bundle's counts. Then the gate:
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/bundle.py" check --design docs/design`,
    which fails on a null or stale audit, on any finding, on a gallery
    that misses a screen and on a missing DESIGN-SYNC.md. Say to open
    `docs/design/index.html`.
11. Feedback loop: ask for comments per screen. Apply each as a surgical
    Edit (a token change lands in tokens.json or tokens.css, never in a
    screen). Re-shoot the screens touched, bump `version` in
    design.json, rerun audit, gallery and check. Append the round to
    `CHANGES.md` with screen, comment, change and `file:line`. Stop when
    the user says done, or after three rounds without a new comment.
12. Print the output contract; name `design-critique` as next. The
    push to a shared design system is the person's: DESIGN-SYNC.md says
    how, and this skill never runs `/design-sync`.

## Output contract

```
## Screen designs: <feature> (round <n>, bundle v<version> | screens as code)
Target: react-shadcn (screens as code) | web | react-native | compose | swiftui
Gallery: http://127.0.0.1:<port>/__design (react-shadcn) | n/a
Path: docs/design/screens/<feature>/   Manifest: docs/design/design.json
Inventory: flows | stories | code | brief   Framework: web | react | react-native | compose | swiftui
Navigation: generated from <flows files> | proposed (ambiguity raised)   Desktop: <chrome>   Mobile: <chrome>
Tokens: docs/design/tokens.css from tokens.json | approved variant | DESIGN.md | brief (proposed); linked | --standalone
Contract: components.md | no contract
Screens: <gallery_check.py or states_check.py counts line, verbatim>
Bundle: <bundle.py check counts line, verbatim>
Concerns: A ambiguity, M missing-screen, U undefined-state, D dead-end, R risk
Events: E on controls | no sheet   Motion: 1 on <id>, reduced-motion guarded | none
Focus: visible   Targets: 44 px
Screenshots: <evidence.py check counts line, verbatim>, console errors 0 | not taken (browse absent)
Review findings fixed: K (generic-default G, screen-level S)
Gallery: docs/design/index.html (open the file)   Sync: docs/design/DESIGN-SYNC.md (a person runs /design-sync)
Rounds: R (CHANGES.md)   Stopped: user said done | 3 rounds without comments
Next: design-critique docs/design/screens/<feature>
```

## Gotchas

- On react-shadcn a raw `<table>`, `<button>` or `<input>` in a view is a
  hand-styled page; gallery_check and design-lint both fail it. Compose
  the component; extend it with a variant in `src/components/ui` when
  the design needs one, never a one-off copy.
- The view takes props and the route wires data: the same component
  renders the gallery state and the live page, so a design change is one
  edit.
- The Screens, Bundle and Screenshots lines are the scripts' counts
  lines. A number the scripts did not print is not written, and the
  audit block in design.json is only ever written by `bundle.py audit`.
- A state panel is the whole screen in its chrome, not a card floating
  on a blank page. A reviewer who cannot see where the screen sits in
  the product will ask, and a developer will guess.
- The annotation says what changed from the default and why ("the list
  keeps its header and filters while rows load, so the person can
  change the filter before the data arrives"), not the state's name
  again.
- A link to a screen nobody designed reads as an unfinished screen in a
  client review and becomes a route in the build. Out-of-scope
  destinations are plain text in the chrome plus a `missing-screen`
  concern, never an `href`.
- The 375 px frame is designed on its own terms: its order, the primary
  action docked above the tab bar, context cut to one line. A squeezed
  desktop fails the self-review even when it has no horizontal scroll.
- Screens link `../../tokens.css`; a copied token block drifts the first
  time the tokens change. `--standalone` is for sending one file, and
  the audit still reads the copy as tokens, not as hard-coded colour.
- The state bar and annotations are prototype chrome. `#chrome=0` hides
  them for screenshots, and the review never scores them.
- Never invent an event name. No sheet means no `data-event`; the
  flows' `needs event:` markers stay in the redlines as text.
- `data-component` names come from the contract verbatim. A region the
  contract lacks is named by its role and listed in the index as a gap
  for `design-system`.
- One motion moment per feature, on the screen the flows point to. A
  second animation is decoration; cut it.
- Surgical edits in the loop. The user may have edited the file by
  hand; a rewrite loses that and the round's `file:line` trail.
- Never describe a screenshot that was not taken, and never push the
  bundle: `/design-sync` shows a person the exact file list before
  anything lands in a shared design system.
