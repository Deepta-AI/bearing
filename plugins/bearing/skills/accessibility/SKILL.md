---
name: accessibility
description: 'Audits and fixes accessibility to WCAG 2.2 AA on web and mobile, findings at file:line, axe checks in Playwright. Use when asked about "accessibility", "a11y", "WCAG", "screen reader" or "keyboard navigation".'
argument-hint: "[path, route or screen to limit; default: every page or screen]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(git status:*), Bash(git diff:*), Bash(make:*), Bash(node:*), Bash(pnpm exec playwright:*), Bash(uv run pytest:*), Bash(go test:*), Bash(python3 -m http.server:*), Bash(kill:*), Bash(python3 *skills/accessibility/scripts/contrast.py*)
---

# accessibility

Accessibility is a gate, not a polish step. This skill finds what fails
for a keyboard user, a screen-reader user and a low-vision user, fixes it
at the source, leaves a gate in CI that fails when it comes back, and
says plainly what could not be checked from here.

## Inputs

- Scope: `$ARGUMENTS`; else the screens the request names (a "signup"
  ticket is the signup flow: its template, its script, its styles, the
  shared layout it renders in and the page it lands on); else every
  screen. Find screens by what the repo is, not by one framework:
  - SPA routers: `createBrowserRouter`, `<Route`, `src/app/`, `pages/`.
  - Server-rendered: route handlers (`http.createServer`, `app.get(`,
    `@app.route`, `HandleFunc`, `router.GET`) and the templates they
    render (`views/`, `templates/`, `*.html`, `*.ejs`, `*.hbs`,
    `*.jinja*`, `*.tmpl`, functions returning HTML strings).
  - Mobile: every file under `app/` (Expo Router, including `[id]`
    dynamic routes and `_layout` files, which hold tab bars and app-wide
    defaults), `@Composable` screens, SwiftUI `View`s.
  Nothing found: one question for a path.
- Constraints: `docs/adr/`, `CONTRIBUTING*`, the CI file and the manifest,
  read before choosing any fix or gate. An accepted ADR (no new
  dependencies, must work without JavaScript, font scaling off) binds
  the fix; Gotchas covers one that conflicts with WCAG.
- Wording: `docs/design/*` copy first, then the visible text. Never a
  name derived from a variable, icon or handler (`toggle`, `eye`,
  `onFilt`, `share-outline`). With neither, the finding stays open as
  "label wording needed".
- Colours: the rendered values in the stylesheet or theme file. A tokens
  document's ratios are claims until measured.
- Checklist: `references/a11y-checklist.md`, the stack's section.
- Engine for a live web page: the AccessLint plugin
  (`accesslint:accessibility-audit`) when the Skill tool can load it and
  a page answers locally; else axe through Playwright when the repo has
  Playwright installed; else the static pass alone, reported as partial.
  The audit must be complete without any engine.

## Steps

1. List the screens in scope with their source files, and the ones left
   out on purpose (owned elsewhere, outside the flow) with why.
2. Check what can run before running anything. `ls node_modules` (or the
   stack's equivalent) first: when dependencies are absent, run no
   `pnpm`, `npm` or `yarn` script at all, because pnpm 10+ and some npm
   setups install from the network before a script runs. Report "type
   check and tests not run: no node_modules" instead. `node --test`,
   `make check` with no install step, `go test` and `uv run pytest` on an
   offline cache are fine.
3. Static pass per screen: grep for candidates (the checklist lists the
   greps), then read each hit in context. For every control on the
   screen answer four questions: its role, its name, its state, and
   whether a keyboard or switch user can reach and operate it. Then walk
   the flow end to end as the user in the ticket would, including the
   failure path (submit with errors) and the success path (what the
   screen says after it worked).
4. Measure every colour pair that carries text or identifies a control:
   `python3 ${CLAUDE_PLUGIN_ROOT}/skills/accessibility/scripts/contrast.py '#9ca3af:#ffffff' '#e5e7eb:#ffffff:3'`
   Text needs 4.5:1 (3:1 at 24 px, or 18.66 px bold). Field borders,
   toggle tracks, focus indicators and meaningful icons need 3:1 (1.4.11)
   when they are what shows the control. State each measured ratio in the
   report and correct any document that claims otherwise. Measure the
   replacements too, and never report a passing pair as failing.
5. Dynamic pass where something can run. A dependency-free server can be
   started with `node` or `python3 -m http.server` on a free port and
   stopped by its own process id with `kill`; then AccessLint, or
   Playwright if installed. Without a browser, render the templates in a
   test (step 7) and say the page was not exercised with a real keyboard
   or screen reader. Mobile is always static; list the device checks.
6. Fix at the source, smallest correct change:
   - A shared component fixes every caller: make the label a required
     prop and pass it at every call site, rather than patching one screen.
   - Native elements over ARIA: `button`, `label for`, `fieldset` and
     `legend` around native radios, `dialog` with `showModal()`; on
     mobile, `accessibilityRole` plus `accessibilityState` on custom
     controls. Native controls also keep a form working without scripts.
   - Leave files outside the scope alone; report their findings.
   - A fix that needs a new dependency, a reversed decision or a design
     change is not quick: leave it open with what it needs.
7. Leave a regression gate inside the existing CI command:
   - Playwright present and dependencies allowed: `e2e/a11y.spec.ts`
     from the checklist pattern (`@axe-core/playwright` is a new
     dependency; name it).
   - Otherwise a test on the runner the repo already has (`node:test`,
     pytest, `go test`, jest) that renders each page in scope in its
     normal and error states and asserts the structural rules: every
     form control has a label, every error is referenced by
     `aria-describedby` from its control, no positive `tabindex`, `html`
     has `lang`, icon-only buttons have a name. It counts what it checked
     and fails when it found zero controls.
   - Prove it bites: break one rule by hand (drop a label, drop a
     `describedby`), run it, see it fail, restore. A gate never seen
     failing is not a gate.
   - Mobile with no test renderer installed: name the test to add and the
     dependency it needs as open, rather than writing one that cannot run.
8. Report (Output contract): every finding with file and line, the WCAG
   2.2 criterion or platform guideline, severity, and fixed or open.
   Close with what was not verified.

## Output contract

```
## Accessibility: <stack> (<N> screens, <M> findings, <F> fixed, <O> open)
| Sev | Screen | file:line | WCAG | Finding | Status |
Measured contrast: <fg> on <bg> = <r>:1 (needs <n>:1) ... (documents corrected)
Decisions in the way: <ADR or constraint, what it blocks, what is proposed>
Gate: <test file, command, what it asserts, seen failing: yes or no>
Not verified: <screen reader, keyboard in a real browser, device text size, build or tests not run and why>
```

Severity: Critical (a flow cannot be completed with a keyboard or screen
reader, or text cannot be enlarged anywhere in the app), High (a level A
failure), Medium (AA), Low (best practice). No conformance claim: code
review and automated checks cannot establish WCAG or EN 301 549
conformance, so the report names the checks that remain.

## Gotchas

- Label in name (2.5.3): `aria-label` on a control with visible text
  replaces that text; "Submit form" on a "Create account" button breaks
  voice control. Use it on icon-only controls only.
- A `div` with `tabindex` and a key handler is still a finding; the fix is
  a native control. A `span` that toggles a checkbox on click is a
  missing `label`.
- Errors on a server-rendered form: after a failed POST the page reloads
  and a screen reader starts at the top, hearing nothing about the
  failure. Put "Error:" in the `title`, render an error summary at the top
  of the form linking to each field, and on each invalid control set
  `aria-invalid="true"` and `aria-describedby` to its message id (hint
  and error both, space separated). For a radio group put them on the
  radios, not only on the `fieldset`, where describedby is announced
  inconsistently.
- Identify input purpose (1.3.5, AA): name, email, tel, address and
  password fields need `autocomplete` (`name`, `email`, `new-password`).
- Target size: web 24 by 24 CSS px minimum (2.5.8); iOS 44 pt, Android
  48 dp. `hitSlop` 8 on a 28 pt button reaches 44, not 48: use 10, or a
  48 minimum size.
- Non-text contrast (1.4.11): a field whose only boundary is a 1.2:1 grey
  border fails, whatever the tokens document calls "decorative". So does
  an off-state toggle track at that contrast.
- Focus: deleting `outline: none` is half the fix; the ring must reach
  3:1 and not sit under sticky elements (2.4.11).
- Progressive enhancement: a `href="#"` link or a control that works only
  through a script fails any requirement to work without JavaScript.
  Give the link a real target.
- Dialogs: `dialog.showModal()` gives modal semantics, focus containment
  and Escape; focus must still return to the opener on close, and the
  close button needs a name (not a bare `&times;`).
- Status messages (4.1.3): RN `accessibilityLiveRegion` is Android only;
  iOS needs `AccessibilityInfo.announceForAccessibility` or
  `accessibilityRole="alert"`. On the web, `role="status"` or
  `role="alert"` on a region that exists before its text changes.
- Mobile traps a quick read misses: masked values ("••••") are read as
  bullets, so label them ("Balance hidden"); a list row built from
  several `Text` nodes needs one focusable element with a role and a
  combined label; an image labelled "logo" should say the brand or be
  hidden; a chart needs a text alternative built from its data (months
  and values), not "chart"; `orientation: "portrait"` fails 1.3.4 unless
  essential.
- Money, legal and data-deleting actions (3.3.4, AA): the submission must
  be reversible, checked, or confirmed on a review step. A one-tap send
  with no review is a finding even when every control is labelled.
- An accepted decision that conflicts with WCAG (font scaling off,
  `user-scalable=no`, a fixed-height layout): report the failure at its
  real severity, cite the ADR, and fix the cause the ADR names where
  cheap (a fixed `height` becomes `minHeight`, or one element gets
  `maxFontSizeMultiplier`). Reversing the ADR is the team's call: leave
  it open as "needs ADR NNNN revisited", or change it and write the
  superseding decision as Proposed. Never flip it silently.
- A tokens or design document that disagrees with the measured ratio is
  wrong until measured otherwise: fix the colour and the document, or
  name the contradiction.
- Security in the same flow earns a line: an unescaped value interpolated
  into the page that follows the form (XSS) is reported even in an
  accessibility pass.
- axe and AccessLint find roughly a third of failures and nothing about
  wording, reading order or whether an announcement makes sense. A green
  automated run is not an audit.
- Never lower the checklist to make a screen pass. A finding the team
  accepts stays in the report as `accepted` with a task id.
