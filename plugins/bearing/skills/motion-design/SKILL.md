---
name: motion-design
description: 'Writes the motion spec and tokens and builds a requested animation (hero, page transition, interaction) with a reduced-motion path. Use when asked to "add animation", "animate this" or "respect reduced motion".'
argument-hint: "[what to animate: hero | banner | page transition | <component> <interaction>] [--stack web|react-native|android|ios] [--doc-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(make:*), Bash(git diff:*), Bash(pnpm exec playwright:*), Bash(pnpm test:*), Bash(node --test:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(python3 *skills/motion-design/scripts/motion_check.py*)
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
- Test runner: the repo's own (`make check`, `node --test`, jest-expo,
  JUnit, XCTest); Playwright only when `@playwright/test` is already a
  dependency. Installed only if `node_modules` (or the platform's
  equivalent) is present; otherwise tests are written and reported
  "not run".
- Motion gate: `scripts/motion_check.py` in this skill, Python 3 only.
  It counts animations per stack from the files, the properties they
  move outside transform and opacity, and those without a
  reduced-motion path; the header of the script lists what it reads.

## Steps

1. Resolve the inputs. Before choosing a library, read the constraints
   that outrank the catalogue: `docs/adr/`, the README's release notes
   (Expo dev client or EAS Update, "no build step", "no dependencies")
   and `package.json`. On React Native, Reanimated, Moti (it needs
   Reanimated), gesture-handler and Lottie are native modules: when an
   ADR or an over-the-air release channel rules out native changes, use
   core `Animated` with `useNativeDriver: true` and `LayoutAnimation`,
   and say why. On a no-build web page, no library and no CDN script.
   When a design note and the tokens disagree (a stale "200 ms" in
   DESIGN.md), the generated tokens win; name the conflict in the report.
2. Classify the request against the catalogue in `templates/motion.md`
   (flow transition, micro-interaction, feedback, special moment,
   ambient, scroll-driven) and check the page's budget: one orchestrated
   moment per page. Write `docs/design/motion.md` from the template only
   on `--doc-only` or when asked for the spec; when it exists, append one
   row per animation to "Applied in this product" and never rewrite it.
3. Find every existing rule that will fight the new motion before
   writing any: `transition: all` or a literal duration on the element,
   an `aria-live` region around text that will change per frame, a
   `height` animation or `useNativeDriver: false`, a hard-coded height
   that clips content, and where the data refreshes or the list
   re-renders (see "State and timing traps").
4. Implement. Durations and easings come from the tokens, never
   literals. Only `transform` and `opacity` change; a request that needs
   `height` gets a measured FLIP, a `scaleY`, natural layout plus a fade,
   or (React Native) `LayoutAnimation`. For a hero or banner, start from
   `templates/hero.html` or `templates/banner.html` and keep the
   structure: scripted timeline, pause control for anything that loops,
   final state reachable without the animation. The default markup and
   CSS are the end state; the script adds the start state, so a failed
   or skipped script never leaves anything hidden.
5. Reduced motion in the same change, through one function or hook that
   every animation reads: web `prefers-reduced-motion` in CSS and
   `matchMedia` (with its `change` event) in scripts; RN
   `AccessibilityInfo.isReduceMotionEnabled` plus the
   `reduceMotionChanged` listener (or Reanimated `useReducedMotion` when
   installed); Android `LocalReducedMotion` from the animator scale; iOS
   `accessibilityReduceMotion`. Search the settings screens and stores
   for an in-app "reduce animations" or "motion" preference and OR it
   with the OS value. The reduced path keeps the end state and the
   meaning: the check mark still shows, the row still leaves, the notes
   still open in full, the final number is still there; only the
   movement goes (a cut, or a plain fade).
6. Accessibility: no autoplaying loop over 5 seconds without a pause
   control; nothing flashing over 3 times per second; no motion on text
   while it is read; meaning carried by motion is also announced
   (`announceForAccessibility`, a live region on the undo bar, or text).
   Animated digits are hidden from assistive technology with the final
   value exposed once: the element's text content holds the figure once,
   not a visible copy plus a hidden copy that copy-paste picks up twice.
7. Test the logic, not the pixels. Put the frame logic in a pure
   function (value and text at progress t, the reduced-motion decision,
   the refresh start value) and test it with the repo's own runner:
   an intermediate frame is a properly formatted string, the last frame
   equals the formatter's output exactly, duration 0 gives the end value
   at once, a null or missing value never animates. On mobile, test the
   reduced-motion branch and that completion and undo still happen.
   Write a Playwright check (final state visible with opacity 1, and
   `getAnimations().length === 0` under `reducedMotion: 'reduce'`) only
   when `@playwright/test` is already a dependency with its browsers
   installed; otherwise say the browser check was not run.
   Never run a test command that installs: with no `node_modules`,
   a package manager's test script (recent pnpm, for one) may
   install the whole tree first. Check first; when
   dependencies are absent, say the tests and type check were not run.
8. The motion gate over every file this change touched plus the shared
   tokens module:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/motion-design/scripts/motion_check.py" --shared <tokens file> <changed files>...`
   (changed files from `git diff --name-only`; drop `--shared` when there
   is no tokens module). It prints a `problem:` line with `file:line` per
   property outside transform and opacity and per animation without a
   reduced-motion path, and exits 1 on either or on zero files or zero
   animations. Fix and rerun until it exits 0. Run `make check` when it
   exists. Never claim the motion was seen unless a browser or device ran.

## State and timing traps

These are where a smooth-looking animation ships a wrong screen.

- Animate on appearance and on change, never on every render. A poll or
  refresh that re-renders must not replay the entrance or count from
  zero: keep the last displayed value per element and animate from it,
  or animate only the first load. A value that was null ("n/a") and is
  now a number is shown at once (or counted from 0): interpolating from
  null gives NaN, which a formatter turns into "n/a" or "NaN" mid-count.
- Enter with the data, not before it. An entrance that plays on page
  open over empty placeholder cards, then numbers that pop in later,
  is the dead load the person complained about. Start the entrance and
  the count in the same frame as the first render of real data.
- Format every frame with the product's formatter (currency, grouping,
  percent digits), and end on exactly its output for the real value, not
  on the last interpolated float. Use tabular numerals so the width holds.
- Read token durations with their unit. `getComputedStyle(root)
  .getPropertyValue('--duration-base')` returns text such as `240ms`,
  ` 0.24s` or `0s`; `parseFloat` alone reads `0.24s` as 0.24 ms. Parse
  `s` and `ms`, and when the duration is 0 (reduced motion zeroes the
  tokens) write the end state synchronously: progress `elapsed / 0` is
  NaN or Infinity.
- The state change does not wait on the animation. Commit the model
  change (complete, delete, navigate) whether or not the animation
  finished: `start(({ finished }) => ...)` gets `finished: false` when
  the row unmounts, is recycled or the screen is left, and a commit
  guarded by `finished` silently loses the action. Ignore a second
  press on the same row while its exit runs, and let two different rows
  complete back to back without one cancelling the other.
- Exit animations leave values behind. A row brought back by undo, or
  a recycled list cell, must start from opacity 1 and scale 1: reset the
  animated values on remount or key them to the item.
- `LayoutAnimation.configureNext` animates the whole next layout pass;
  call it in the same tick as the state change that removes the row,
  and build it with `LayoutAnimation.create(<token duration>, ...)`. It
  takes a preset curve, not a bezier; say so rather than invent a
  literal. On the old architecture Android also needs
  `UIManager.setLayoutAnimationEnabledExperimental(true)`.
- A clipped expander is a content bug before it is a motion bug:
  measure the content (`onLayout`) or let it lay out naturally, never
  cap it at a guessed height.

## Output contract

```
## Motion: <request> (<stack>, approach: <minimal-functional | intentional | expressive>)
doc: docs/design/motion.md (written | row appended | none)
tokens: docs/design/tokens.json | theme file | defaults; constraints read: <ADR, release channel, dependency rule>
| where | pattern | library | reduced-motion path | test |
patterns applied: <P> (<pattern names>)
motion gate: <motion_check.py counts line, verbatim>
loops over 5 s with pause control: <n of n>; flashes over 3 per second: 0
gate: make check: passed | failed (<target>) | no Makefile
not run: <tests, type check, browser or device checks that did not run>
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
  `AccessibilityInfo.isReduceMotionEnabled` is async and starts false;
  subscribe to `reduceMotionChanged` too.
- Compose `animateContentSize` animates height (a layout property);
  prefer `AnimatedVisibility` with fade and a scale.
- SwiftUI `withAnimation` around a state change animates every
  dependent view; scope it with `.animation(_, value:)`.
- A count-up that writes the live value into an `aria-live` region
  reads every frame aloud; keep the final value in the markup and the
  region off during the count.
