---
name: accessibility
description: 'Audits and fixes accessibility to WCAG 2.2 AA on web and mobile, findings at file:line, axe checks in Playwright. Use when asked about "accessibility", "a11y", "WCAG", "screen reader" or "keyboard navigation".'
argument-hint: "[path, route or screen to limit; default: every page or screen]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(pnpm exec playwright:*), Bash(pnpm install:*), Bash(make:*), Bash(git diff:*)
---

# accessibility

Accessibility is a gate, not a polish step. This skill walks every screen
against `references/a11y-checklist.md`, fixes what a linter could have
fixed, and hands the rest back with a file and a line.

## Inputs

- Scope: `$ARGUMENTS`; if absent, the routes in `src/app/routes.tsx`
  (web), else any router file found by grep (`createBrowserRouter`,
  `<Route`, `next/app` pages), every file under `app/` (Expo Router),
  every `@Composable` screen under `ui/` (Android), every `View` under
  `Features/` (iOS); if still nothing, every `.tsx`, `.kt` or `.swift`
  file that renders UI. Zero UI files: one question for a path. Nothing:
  stop with "provide a path to a page, screen or component".
- Stack: from the files found and the package manifest.
- Checklist: `references/a11y-checklist.md` in this skill's folder.
- Web engine: the AccessLint plugin (`accesslint:accessibility-audit`,
  `accesslint:accessibility-scan`, `accesslint:accessibility-inspect`,
  `accesslint:accessibility-fix`) when installed and the app answers at a
  local or qa URL; it drives Chrome over CDP against the live page and is
  web only. If absent, or no page is running, the Playwright pass below.
- Runner: Playwright (`playwright.config.*` or `e2e/`); if absent, the
  dynamic pass is `n/a (no Playwright)` and the report prints the command
  to add it; the static pass runs regardless.
- TC ids: `docs/testing/test-cases.md`; if absent, axe tests are named by
  route and `test-cases` can add ids later.
- Design copy for label wording: the visible text or `docs/design/*`;
  if absent, the finding stays open as "label wording needed".

## Steps

1. Resolve the scope as in Inputs and list the screens with their source.
2. Read the stack's section of `references/a11y-checklist.md` once.
3. Static pass per screen, grep first, then read the hits in context:
   - Web: `div` or `span` with `onClick`; `img` without `alt`; icon-only
     `button` without `aria-label`; `input` without a `label` or
     `aria-labelledby`; error text not linked by `aria-describedby`;
     dialogs without focus trap and return; loading regions without
     `role="status"` or `aria-live`; `tabIndex` above 0; `outline-none`
     without a `focus-visible` ring; colour tokens below 4.5:1 (3:1 for
     large text and UI parts); target size under 24 by 24 px.
   - React Native: `Pressable` or `Touchable*` without `accessibilityRole`;
     icon buttons without `accessibilityLabel`; toggles without
     `accessibilityState`; hit area under 44 pt with no `hitSlop`.
   - Android: `Image` or `Icon` without `contentDescription` (`null` only
     when decorative); clickable `Modifier` without `Role`; custom controls
     without `semantics`; text sizes in `dp` instead of `sp`; touch targets
     under 48 dp.
   - iOS: interactive views without `accessibilityLabel`; decorative images
     not `accessibilityHidden`; fixed font sizes instead of Dynamic Type;
     frames that clip at the largest accessibility size; grouped rows
     without `.accessibilityElement(children: .combine)`.
4. Dynamic pass where a runner exists. Web with AccessLint and a live
   URL: invoke `accesslint:accessibility-audit` (Skill tool) for two or
   more routes, or `accesslint:accessibility-scan` then
   `accesslint:accessibility-inspect` for one. Carry its findings into
   this report: its `file:line` when its source map gives one, else the
   selector; its evidence mark (● verified, ◐ flagged, ○ human-required)
   in the Finding column; severity from the checklist's mapping by
   criterion, with its critical kept as Critical. Its ◐, ○ and not
   exercised criteria are open, never passed. Web without it: axe
   through Playwright on every route with the WCAG 2.2 AA tags, then a keyboard-only pass: Tab through
   the page, assert the focus order matches the reading order, every
   control is reachable, Escape closes dialogs, focus returns to the
   opener. Mobile: list the checks that need a device (TalkBack, VoiceOver,
   Dynamic Type at the largest size) as manual, with the screen name.
5. Fix the mechanical findings in place. Web findings from AccessLint go
   to `accesslint:accessibility-fix` as a worklist (Skill tool), which
   edits and re-runs its baseline to verify; mobile findings are fixed
   here. The fixes: missing `alt`, `aria-label`,
   `accessibilityRole`, `accessibilityLabel`, `contentDescription`,
   `role="status"`, a native `button` for a clickable `div`. Take label
   wording from the visible copy or the design, never from a variable name;
   with neither, leave the finding open as "label wording needed".
6. When Playwright exists and no axe spec does, add `e2e/a11y.spec.ts` from
   the spec pattern in the checklist, one test per route, named with its
   TC id when the case table has one. Add it whichever engine ran step 4:
   it is the standing gate in CI, and AccessLint adds none to the repo. `@axe-core/playwright` is a new
   dependency: say so before adding it.
7. Print the report. Severity: Critical (no keyboard or screen-reader path
   through a flow), High (a WCAG A failure), Medium (an AA failure), Low
   (best practice).

## Output contract

```
## Accessibility: <stack> (<N> screens audited, <M> findings, <F> fixed)
| Severity | Screen | file:line | Criterion | Finding | Status |
...
Fixed: F   Open: M-F (each with what is needed)
Manual checks on a device: ...
Engine: AccessLint audit | axe via Playwright | static only (partial)
Axe spec: added | present | n/a (no Playwright; add with pnpm add -D @playwright/test @axe-core/playwright)
```

## Gotchas

- axe finds roughly a third of WCAG failures. A green axe run without the
  keyboard pass is not an audit, and a static-only run (no Playwright) is
  a partial audit; the report says which it was.
- A `div` made focusable with `tabIndex` and `onKeyDown` is still a
  finding. The fix is a `button`.
- `aria-label` on an element with visible text replaces that text for
  screen readers. Use it on icon-only controls, nowhere else.
- Contrast is measured on the rendered colour, not the token name.
  `text-gray-400` on white fails at about 2.5:1.
- `@axe-core/playwright` is a new dependency; `definition-of-done` item 7 will ask
  about it, so name it in the report.
- AccessLint needs a running page and Chrome; it cannot read React
  Native, Compose or SwiftUI source. Mobile screens always take the
  static pass here, even when AccessLint ran for the web app.
- Never lower the checklist to make a screen pass. A finding the team
  accepts stays in the report as `accepted` with a task id.
