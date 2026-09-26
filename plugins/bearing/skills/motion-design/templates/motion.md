# Motion: <Product>

<!-- Template guidance: this product's motion spec: the principles, the
     motion tokens, the rules every animation obeys, the catalogue of
     patterns per stack, and the table of what is applied where.
     Engineers read it before animating anything and reviewers check a
     change against it. motion-design refreshes the top sections and only
     appends to "Applied in this product". The catalogue below is the
     kit's default; keep the entries the product can use. Delete each
     comment when you fill its section. -->

Written by `motion-design`. Tokens come from `docs/design/tokens.json`
(`motion.duration`, `motion.easing`, `motion.stagger`); this file says
what to do with them. When a pattern here and the tokens disagree, the
tokens win.

## Principles

<!-- What: the rules that decide whether an animation exists at all, set
     to the product's approach (minimal-functional, intentional or
     expressive) from DESIGN.md.
     Good: every animation says what changed, where something went, or
     that the system is working; one orchestrated moment per page, named
     here once it is chosen; reduced motion keeps the meaning.
     Example: "The orchestrated moment is the booking confirmation on
     /book/done; every other page is quiet." -->

1. Purpose. Every animation says one of three things: what changed,
   where something came from or went, or that the system is working.
   An animation that says none of these is cut.
2. One orchestrated moment per page. The page's signature (a hero, a
   first-run sequence, a result reveal) gets the choreography.
   Everything else is quiet: state changes at `fast`, entrances at
   `base`, nothing slower than `deliberate` outside the moment.
3. Movement is earned. Opacity first; add transform when position
   carries meaning (a sheet comes from the edge it returns to).
4. Text is read, not watched. No motion on text while it can be read;
   entrances finish before reading starts.
5. Motion is a preference. `prefers-reduced-motion` and the platform
   equivalents zero every duration and replace movement with a fade or
   with nothing. The meaning never disappears with the movement.

## Tokens

<!-- What: the motion tokens with their values and use, and where each
     stack reads them.
     Good: values copied from motion.* in tokens.json, or the report says
     "tokens: defaults" when there is no tokens file; the Use column
     names real components so a reader can pick a token without asking.
     Example: | `duration.base` | 240 ms | appointment sheet entrance,
     tab indicator | -->

| Token | Value | Use |
| --- | --- | --- |
| `duration.instant` | 80 ms | press feedback, hover colour, toggle thumb |
| `duration.fast` | 150 ms | state changes, tooltip, focus ring, exits |
| `duration.base` | 240 ms | entrances, dialogs, tab indicator, list reorder |
| `duration.slow` | 400 ms | page and route transitions, sheets |
| `duration.deliberate` | 700 ms | the orchestrated moment, count-ups, skeleton period |
| `easing.standard` | `cubic-bezier(0.2, 0, 0, 1)` | anything that moves and stays on screen |
| `easing.enter` | `cubic-bezier(0, 0, 0.2, 1)` | arriving: decelerate |
| `easing.exit` | `cubic-bezier(0.4, 0, 1, 1)` | leaving: accelerate |
| `easing.spring` | stiffness 300, damping 30, mass 1 | drag settle, toggle thumb, pull to refresh |
| `stagger` | 40 ms | gap between siblings in an orchestrated entrance; cap at 8 items |

Per stack the tokens are read from the generated theme file
(`--duration-base` and `--ease-enter` on the web, `duration.base` in
`theme.ts`, `Duration.Base` in Kotlin, `Duration.base` in Swift).

## Rules that apply to every pattern

<!-- What: performance, reduced-motion, accessibility and test rules that
     hold for every pattern on every stack.
     Good: transform and opacity only (motion_check.py fails anything
     else, and transition: all); a reduced-motion path on each stack that
     keeps the end state; no loop over 5 seconds without a pause, nothing
     flashing over 3 times per second; a test that reaches the final
     state with reduced motion on.
     Example: "Tests: e2e/motion/booking-done.spec.ts runs with
     reducedMotion 'reduce' and expects getAnimations().length 0." -->

- Performance: animate `transform` and `opacity` only. Never `width`,
  `height`, `top`, `left`, `margin`, `padding`, `box-shadow` or
  `filter` on more than one element. `will-change` only during the
  animation. 60 fps on a mid-range phone is the budget; a pattern that
  drops frames is simplified, not shortened.
- Reduced motion: web `@media (prefers-reduced-motion: reduce)` and
  `matchMedia` in scripts; React Native
  `AccessibilityInfo.isReduceMotionEnabled` and `useReducedMotion`
  from Reanimated; Android `Settings.Global.ANIMATOR_DURATION_SCALE`
  equals 0 (read once, then `LocalReducedMotion`); iOS
  `accessibilityReduceMotion` from the environment. The fallback keeps
  the end state and the meaning: fade instead of slide, cut instead of
  fade, static instead of loop.
- Accessibility: no autoplaying loop longer than 5 seconds without a
  visible pause control; nothing flashes more than 3 times per second;
  motion never blocks input (a press works mid-animation); a
  screen-reader announcement replaces any meaning carried by motion.
- Tests: Playwright checks the final state (position, opacity 1,
  attribute) and, with `reducedMotion: 'reduce'`, that the element
  reaches the same end state with no animation running
  (`getAnimations().length === 0` or duration 0). Mobile: a unit test
  on the reduced-motion branch of the hook or modifier.

## Catalogue

<!-- What: every pattern the product may use, grouped as below: when to
     use it, the implementation per stack with its library and the
     reason, the reduced-motion fallback and the test.
     Good: a request outside the catalogue gets a new entry here, with its
     reduced-motion fallback, before any code; every fallback keeps the
     end state and the meaning (fade, cut or static, never a missing
     element).
     Example: "Tooltip. Fades in at fast after 400 ms of hover or on
     focus; Reduced: appears at once; Test: visible with opacity 1." -->

Each pattern: when to use it, the implementation per stack with the
library and the reason, the reduced-motion fallback, the test.

### Flow transitions

<!-- What: movement between pages, routes and states of a list: page
     transitions, shared elements, reorder and insert.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     Only one shared element per transition; the chrome stays still.
     Example: "Page and route transition. Content cross-fades at slow;
     Reduced: cut; Test: the new route's heading is visible." -->

**Page and route transition.** Content areas cross-fade at `slow`
with `enter` and `exit`; the chrome stays still. Web: the View
Transitions API (`document.startViewTransition`, `view-transition-name`
on the moving parts; it is native, no dependency, and falls back to a
cut), Motion One or Framer Motion `AnimatePresence` where the router
already uses React and needs exit animations. React Native:
`expo-router` stack animation `slide_from_right` (iOS) and `fade`
(Android), Reanimated shared transitions only on the same screen
family. Android: `NavHost` `enterTransition` and `exitTransition` with
`fadeIn(tween(Duration.Slow))` plus a 4 percent `slideIn`. iOS:
`NavigationStack` default push; `.transition(.opacity)` on swapped
content. Reduced: cut. Test: after navigation the new route's heading
is visible and the old one absent.

**Shared element.** A card that opens into its detail keeps its image
in place. Web: `view-transition-name` on the image in both pages.
React Native: Reanimated `sharedTransitionTag`. Android: Compose
`SharedTransitionLayout` with `sharedElement`. iOS:
`matchedGeometryEffect` in a `Namespace`. Only for one element per
transition; two shared elements read as chaos. Reduced: cross-fade.

**List reorder and insert.** Rows move to their new slot at `base` with
`standard`; a new row fades in; a removed row fades out at `fast`
before the others move. Web: FLIP through Motion One `animate` with
`layout`, or Framer Motion `layout` prop. React Native: Reanimated
`Layout` transitions (`LinearTransition`) plus `FadeIn` and `FadeOut`.
Android: `Modifier.animateItem()` in `LazyColumn`. iOS: `withAnimation`
around the array change with `.animation(.default, value:)`. Reduced:
no movement, fades only.

### Micro-interactions

<!-- What: the small responses to a single input: press, hover and focus,
     toggles, form validation.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     The focus ring never animates; validation never shakes.
     Example: "Press. Scale to 0.97 at instant, back with spring;
     Reduced: colour change only." -->

**Press.** Scale to 0.97 at `instant`, back with `spring`. Web: CSS
`:active { transform: scale(0.97) }` with `transition: transform
var(--duration-instant)`. React Native: Reanimated `useAnimatedStyle`
with `withSpring` on `pressed`, or Moti `animate={{ scale }}` for one
liners. Android: `Modifier.scale(animateFloatAsState(if (pressed)
0.97f else 1f, spring()))` from `interactionSource`. iOS: a
`ButtonStyle` with `configuration.isPressed` and `.scaleEffect`.
Reduced: colour change only.

**Hover and focus.** Colour at `instant`; the focus ring appears with
no animation (it must be instant for keyboard users). Web only for
hover; focus on every stack is a static ring.

**Toggle, checkbox, switch.** The thumb travels with `spring`; the
check mark draws at `fast` (SVG `stroke-dashoffset` on the web,
`AnimatedVisibility` on Android, `.trim` on iOS, Reanimated
`withTiming` on RN). Reduced: cut to the end state.

**Form validation.** The error line fades in at `fast`; the field
border changes colour; no shake (a shake is motion on text). The
error text is announced through `aria-describedby` or the platform
error API. Reduced: same, without the fade.

### Feedback

<!-- What: motion that says the system is working or has finished:
     skeletons, progress, success and error moments.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     An indeterminate indicator that can last over 5 seconds carries a
     pause control.
     Example: "Loading skeleton. Opacity pulse with a deliberate period,
     shown after 300 ms; Reduced: static at 0.8." -->

**Loading skeleton.** Opacity pulse between 1 and 0.55 with a
`deliberate` period, one region at a time, shown after 300 ms and kept
for at least 500 ms. Reduced: static at 0.8.

**Progress.** Determinate bars move with `transform: scaleX` at
`base`; indeterminate bars translate a segment at `deliberate` and
carry a pause control when they can last over 5 seconds. Reduced:
determinate stays; indeterminate becomes a static stripe with text.

**Success and error moments.** A check mark draws at `base`, the
container settles with `spring`; an error state fades at `fast` and
does not move. A toast enters from its edge at `base` and leaves at
`fast`. Reduced: fades.

### Special moments

<!-- What: the orchestrated moment and its kin: hero, banner, launch,
     count-up, celebration.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     One per page, 3 to 6 steps under 1.5 seconds, built from
     templates/hero.html or templates/banner.html; its meaning is also
     in text.
     Example: "Count-up. 0 to the value at deliberate, tabular figures,
     final value in the DOM; Reduced: the final number." -->

**Hero and banner.** The one orchestrated moment: a timeline of 3 to 6
steps, total under 1.5 seconds, then everything holds still. Web: the
Web Animations API (`element.animate`) for scripted timelines (native,
pausable, testable), CSS keyframes with `--i` stagger for pure
entrances; Motion One `timeline` when steps must overlap with
callbacks. React Native: Reanimated `withDelay` and `withSequence`;
Moti for declarative staggers. Android: `AnimatedVisibility` with
`delayMillis` per child, or `MotionLayout` for a keyframed scene. iOS:
`.animation(.easeOut.delay(i * stagger), value: shown)` per element,
`PhaseAnimator` for multi-step scenes. `templates/hero.html` and
`templates/banner.html` are the reference implementations. Reduced:
elements appear in the end state with a single 150 ms fade or none.

**Launch and onboarding.** A splash that resolves into the first
screen through a shared element (logo to header); onboarding pages
cross-fade with a shared progress indicator. Never longer than the
data actually needs to load. Reduced: cut.

**Promotional banner.** A scripted timeline that plays once, holds,
and offers replay; a visible pause control if any part loops. See
`templates/banner.html`. Reduced: final frame.

**Number count-up.** From 0 to the value at `deliberate`, easing
`standard`, tabular figures so the width does not jitter, and the
final value in the DOM from the start for screen readers
(`aria-live` off during the count). Web: `requestAnimationFrame` or
Motion One `animate(0, n, { onUpdate })`. Reduced: the final number.

**Celebratory states.** Confetti or a burst at most once per event,
under 1.5 seconds, no loop, and a text confirmation that carries the
meaning. Reduced: text only.

### Ambient motion

<!-- What: background motion that carries no information: gradients and
     particles.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     Marketing and empty surfaces only, never behind text being read;
     paused when hidden or off screen; a pause control past 5 seconds.
     Example: "Background gradient on the empty dashboard: one layer,
     opacity only; Reduced: a static frame." -->

**Background gradients and particles.** Allowed only on marketing and
empty surfaces, never behind text a person is reading. Budget: one
layer, transform or opacity only, under 2 percent CPU on a laptop and
paused when the tab is hidden (`visibilitychange`) or the element is
off screen (`IntersectionObserver`). A loop longer than 5 seconds has a
pause control. Reduced: a static frame.

### Scroll-driven effects

<!-- What: motion tied to scroll position: reveals and parallax.
     Good: a new entry names its library per stack and why, its
     reduced-motion fallback and its test before any code is written;
     durations and easings are token names, never literals.
     A reveal plays once; parallax is one layer, behind non-text
     content, off on mobile.
     Example: "Reveal on scroll. Fade and rise 8 px once at 20 percent
     visible; Reduced: visible from the start." -->

**Reveal on scroll.** Elements fade and rise 8 px once, when 20 percent
visible, at `base` with `enter`. Web: `IntersectionObserver` toggling a
class, or `animation-timeline: view()` where supported. React Native:
Reanimated `useAnimatedScrollHandler`. Android and iOS: none by
default; lists already move. Reduced: visible from the start.

**Parallax.** At most one layer at 10 percent of scroll speed, behind
non-text content, and off on mobile. Web: `animation-timeline:
scroll()` or a transform from the scroll handler. Reduced: static.

## Applied in this product

<!-- What: one row per animation shipped, appended by each motion-design
     run and never rewritten.
     Good: Where is a route or screen; the pattern is a catalogue name;
     the library matches the catalogue for that stack; the reduced-motion
     path and the test file are real paths, and motion_check.py passes
     on them.
     Example: /book/done | Hero and banner | web, Web Animations API |
     end state with one 150 ms fade | e2e/motion/booking-done.spec.ts -->

| Where | Pattern | Stack and library | Reduced-motion path | Test |
| --- | --- | --- | --- | --- |
| <route or screen> | <pattern> | <library> | <fallback> | <test file> |
