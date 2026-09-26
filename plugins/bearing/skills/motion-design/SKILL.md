---
name: motion-design
description: 'Writes the motion spec and tokens and builds a requested animation (hero, page transition, interaction) with a reduced-motion path. Use when asked to "add animation", "animate this" or "respect reduced motion".'
argument-hint: "[what to animate: hero | banner | page transition | <component> <interaction>] [--stack web|react-native|android|ios] [--doc-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(git diff:*), Bash(pnpm exec playwright:*), Bash(pnpm test:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(python3 *skills/motion-design/scripts/motion_check.py*)
---

# motion-design

Motion says what changed, where it went, or that the system is working.
One orchestrated moment per page carries the personality; everything
else is quiet, moves only transform and opacity, and disappears
gracefully when the person asked for less motion.

## Inputs

- Request: `$ARGUMENTS` or the sentence that loaded the skill; if it
  names nothing to animate, write or refresh the document only.
- Tokens: `motion.*` in `docs/design/tokens.json`; if absent, the
  generated theme file (`--duration-*` in `src/styles/tokens.css`,
  `duration` in `theme.ts`, `Duration` in Kotlin or Swift); if absent,
  the values in `templates/motion.md` are used and the report says
  "tokens: defaults; `design-system` writes them".
- Design direction for the motion approach (minimal-functional,
  intentional, expressive): `docs/design/DESIGN.md` or the root
  `DESIGN.md` `## Motion` section; if absent, intentional.
- Catalogue and document template: `templates/motion.md`; reference
  implementations: `templates/hero.html` (orchestrated hero) and
  `templates/banner.html` (scripted timeline with pause control).
- Stack: `--stack`; else `package.json` (`react` web, `expo`
  react-native), `build.gradle.kts` (android), `Package.swift` or
  `*.xcodeproj` (ios); none: document only.
- Test runner: Playwright (`playwright.config.*`), jest-expo, JUnit,
  XCTest; if absent, the test is written next to the animation and
  its command printed.
- Motion gate: `scripts/motion_check.py` in this skill, Python 3 only.
  It counts animations per stack from the files, the properties they
  move outside transform and opacity, and those without a
  reduced-motion path; the header of the script lists what it reads.

## Steps

1. Resolve the inputs. Read `templates/motion.md` once. Write or
   refresh `docs/design/motion.md` from it with the product's tokens
   and approach filled in; keep the "Applied in this product" table
   and append to it, never rewrite it. `--doc-only`: print the
   contract.
2. Classify the request against the catalogue: flow transition,
   micro-interaction, feedback, special moment, ambient, scroll-driven.
   A request outside the catalogue gets a new catalogue entry first,
   with its reduced-motion fallback, before any code.
3. Check the page's budget: one orchestrated moment per page. If the
   page already has one and the request is a second, say so and offer
   to replace it or to make the new one quiet.
4. Implement with the library the catalogue names for the stack:
   CSS transitions, the View Transitions API, the Web Animations API,
   Motion One or Framer Motion on the web; Reanimated and Moti on
   React Native; Compose animation APIs and MotionLayout on Android;
   SwiftUI animations and `matchedGeometryEffect` on iOS. Durations
   and easings come from the tokens, never literals. Only `transform`
   and `opacity` change; a request that needs `height` gets a
   `scaleY` or a measured FLIP instead. For a hero or banner, start
   from the matching template and keep its structure: scripted
   timeline, pause control for anything that loops, final state
   reachable without the animation.
5. Write the reduced-motion path in the same change: web
   `prefers-reduced-motion` in CSS and `matchMedia` in scripts; RN
   `useReducedMotion`; Android `LocalReducedMotion` from the animator
   scale; iOS `accessibilityReduceMotion`. The path keeps the end
   state and the meaning: fade or nothing, never a missing element.
6. Accessibility: no autoplaying loop over 5 seconds without a pause
   control; nothing flashing over 3 times per second; no motion on
   text while it is read; meaning carried by motion is also announced.
7. Test where the stack allows. Playwright: the element reaches its
   final state (visible, opacity 1, transform none, attribute set) and,
   in a context with `reducedMotion: 'reduce'`, the same final state
   with `getAnimations().length === 0`. Mobile: a unit test on the
   reduced-motion branch. Add the test file to the table.
8. The motion gate, which counts from the files, over every file this
   change touched plus the shared tokens module:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/motion-design/scripts/motion_check.py" --shared <tokens file> <changed files>...`
   (take the changed files from `git diff --name-only`; drop `--shared`
   when there is no tokens module). It prints a `problem:` line with
   `file:line` per property outside transform and opacity and per
   animation without a reduced-motion path, and exits 1 on either or on
   zero files or zero animations. Fix and rerun until it exits 0. Run
   `make check` when it exists and print the contract.

## Output contract

```
## Motion: <request> (<stack>, approach: <minimal-functional | intentional | expressive>)
doc: docs/design/motion.md (written | refreshed; <N> catalogue entries, <M> applied rows)
tokens: docs/design/tokens.json | theme file | defaults
| where | pattern | library | reduced-motion path | test |
patterns applied: <P> (<pattern names>)
motion gate: <motion_check.py counts line, verbatim>
loops over 5 s with pause control: <n of n>; flashes over 3 per second: 0
gate: make check: passed | failed (<target>) | no Makefile
```

## Gotchas

- `transition: all` animates layout properties by accident and hides
  a jank source; list the properties.
- The View Transitions API needs a unique `view-transition-name` per
  element on the page; two elements sharing one cancels the whole
  transition silently.
- Framer Motion `layout` on a list inside `overflow: hidden` clips
  the moving rows; measure before choosing it over Motion One.
- Reanimated worklets cannot read React state; pass shared values.
  `AccessibilityInfo.isReduceMotionEnabled` is async; use the hook.
- Compose `animateContentSize` animates height (a layout property);
  prefer `AnimatedVisibility` with fade and a scale.
- SwiftUI `withAnimation` around a state change animates every
  dependent view; scope it with `.animation(_, value:)`.
- A count-up that writes the live value into an `aria-live` region
  reads every frame aloud; keep the final value in the markup and the
  region off during the count.
- The output is written to pass the six-item motion audit in gstack
  `design-review` (easing direction, duration range, purpose, reduced
  motion, no `transition: all`, transform and opacity only).
