---
name: react-native
description: 'React Native house rules (Expo, expo-router, TanStack Query, Zustand, Zod, NativeWind, EAS). Load before writing or changing React Native or Expo code. Use when asked for "an Expo screen", "an EAS build".'
allowed-tools: Read, Grep, Glob, Skill, Bash(pnpm run:*), Bash(pnpm test:*), Bash(npx expo doctor:*), Bash(npx expo export:*), Bash(make:*)
---

# react-native

The mobile stack on this standard: Expo SDK 57 on React Native 0.86 with the new
architecture and Hermes, `expo-router` for file-based navigation, TypeScript
strict, TanStack Query for server state, Zustand for client state, Zod at
every boundary, NativeWind for styling, EAS Build and EAS Update for
delivery, Maestro for end-to-end flows, `jest-expo` with Testing Library for
unit tests, ESLint flat config plus Prettier, pnpm with a hoisted
`node_modules`. One codebase ships iOS and Android.

NativeWind over `StyleSheet`: design tokens live in one `tailwind.config.js`
under the web lanes' role names; a token changed on one side changes on the
other in the same MR.
Detail: references/styling-and-layout.md

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.ts`/`.tsx` files under `app/` or `src/`: apply
  `references/guidelines.md`. Read it once per session, then work.
- Reviewing a diff with mobile files: apply `references/review-checklist.md`
  and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
- Scaffolding (`new-repo react-native <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Pack skills

The Expo team's expo/skills pack tracks the current SDK. When one is
installed, load it with the Skill tool for its job; when
it is not, work from the Expo changelog for the target SDK and name the
missing skill in the report.

- `expo-upgrade`: an Expo SDK bump or a deprecated package; its version floors
  win, the gate after it is `make check` then `make doctor`.
- `expo-router`: native navigation UI; import from `expo-router/react-navigation`,
  never `@react-navigation/*`. Rule 5 still holds.
- `expo-dev-client` is not loaded: its commands are EAS cloud builds the
  repository settings deny. A local dev client comes from `make ios` or
  `make android`.

Detail: references/pack-skills.md

## Layout

Screens under `app/`, feature code under `src/features/<feature>/` (api, schemas,
hooks, components), the `Makefile` the only entry point.
Detail: references/styling-and-layout.md

## On a foreign layout

Hard rules anywhere: 2 (secrets only in the secure store), 3, 5, 6, 7,
8, and no secret in `EXPO_PUBLIC_*` or any bundled variable. Advisory:
the directory layout, expo-router (React Navigation stays where it is),
NativeWind, Zustand, pnpm and EAS: use what the repository already has;
propose a switch in an ADR, never inside a feature change. A bare React
Native app without Expo keeps its own build commands. Say which rule
was relaxed and why.

## Rules that matter most

1. Server state lives only in TanStack Query. Never copy a query result into
   Zustand, `useState` or a ref; read it where it is used.
2. Zustand holds client state (session flags, drafts, UI preferences).
   `persist` through MMKV or `expo-sqlite/localStorage` (Expo deprecates
   AsyncStorage; an existing AsyncStorage store stays until an ADR) only
   for data that is fine to read off a rooted phone. Tokens and anything secret go in `expo-secure-store`,
   never AsyncStorage, never `app.json` `extra`.
3. Zod at every boundary: API responses, deep-link params, persisted state
   on rehydrate, push payloads. Types are derived from schemas, not declared
   twice.
4. Long lists use `FlashList` or `FlatList` with `keyExtractor` and, when
   rows have fixed height, `getItemLayout`. `ScrollView` with `.map` is a
   finding above ten rows. No inline function props on row components
   without a measured reason.
5. Navigation goes through expo-router typed routes; `router.push` takes a
   typed href, never a string built at runtime. Deep links are validated
   with a schema before navigation and never trusted for authorisation.
6. Permissions are requested at the moment of use, after a one-line
   rationale the user can decline, never on launch.
7. Every screen renders loading, error and empty states, and the error
   state has a retry.
8. Every interactive element has `accessibilityRole` and an
   `accessibilityLabel` when its text is not the label. Touch targets are at
   least 44 points.
9. `make check` = Prettier check, ESLint, `tsc --noEmit`, Jest. CI runs the
   same target.

## Traps a strong generalist still ships

Each of these passes a code read and fails a real customer. Check the ones
the task touches, in the code you write and in any diff you review.

Reading the repository
- Docs disagree: the API reference and its changelog beat a README; an
  Accepted ADR beats both. A `z.enum` over a server-owned value fails a page
  on one new value; render an unknown one as a neutral label, never a throw.
  Detail: references/traps-reading-and-writes.md

Paginated lists (`useInfiniteQuery`)
- `getNextPageParam` returns `undefined` at a null cursor; a failed next page
  shows a footer retry, never a full-screen error over loaded rows; set
  `maxPages` on long histories.
  Detail: references/traps-lists-and-links.md

Deep links and sessions
- A signed-out customer who opens a link lands on that target after sign in
  through a validated in-app `next` param. Sign out clears the query cache
  (`queryClient.clear()`, and any persisted cache).
  Detail: references/traps-lists-and-links.md

Writes
- A submit is a `useMutation`; the button is disabled while `isPending`,
  and a failure shows a message with retry.
- A POST that creates something carries an idempotency key generated once per
  user intent, kept across retries. Never default a required choice.
  Detail: references/traps-reading-and-writes.md

Uploads and media
- Files go to a presigned URL the API issues; the app never holds a storage
  key or signing secret. Resize camera photos and check the size against the
  server limit first. Detail: references/traps-uploads-native-tests.md.

Native changes
- A new native module needs its plugin entry and usage strings in `app.json`;
  under `runtimeVersion` policy `appVersion`, bump `version` (or use
  `fingerprint`) and ship a store build before any `eas update` that needs it.
  Detail: references/traps-uploads-native-tests.md.

Tests that count
- Test the hook with `renderHook` and the screen with Testing Library, not
  just a schema. Detail: references/traps-uploads-native-tests.md.

Reviews
- Report only what the branch introduced: diff against the merge base and
  check each finding's line is in that diff. A defect on an untouched line
  of a touched file is pre-existing; list it separately as such.
- A secret already committed is compromised: deleting it is not enough,
  it is rotated. It blocks the merge.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form to run without one.

```
make setup          # pnpm install, git hooks
make dev            # expo start (Expo Go or a dev client)
make ios            # build and run a dev client on the iOS simulator (macOS)
make android        # build and run a dev client on an Android emulator
make check          # prettier --check . ; eslint . ; tsc --noEmit ; jest
make fix            # prettier --write . ; eslint --fix .
make test-e2e       # maestro test .maestro (needs a running simulator or device)
make doctor         # npx expo doctor plus tool versions
make build-preview  # prints the eas build command; runs only with EAS_CONFIRM=1
```

## Gotchas

- Expo Go runs only the modules bundled in it. Any other native module
  (MMKV, a custom SDK, most payment and camera libraries) needs a dev client:
  `make ios` or `make android` once, then `make dev` as usual.
- EAS profiles: `development` builds a dev client, `preview` builds an
  installable internal binary, `production` builds for the stores. Builds
  are the engineer's call, so `make build-preview` refuses without
  `EAS_CONFIRM=1`.
- Hermes is the only engine. No `eval`, no `Function()`, and the debugger is
  the React Native DevTools, not Chrome.
- Android 16 KB page size: from targetSdk 35 every native library must be
  16 KB aligned. Expo's own modules are; a third-party `.so` that is not
  fails on Google Play submission, not at build time.
- iOS privacy manifest: any library reading UserDefaults, file timestamps or
  disk space needs a reason code in `PrivacyInfo.xcprivacy`. Expo generates
  it for its modules; a third-party pod without one is rejected by App
  Store review.
- iOS builds need a macOS runner or EAS cloud; the Linux CI runs export,
  tests and Android only.
- expo-router typed routes are generated into `.expo/types` by `expo
  start` or `expo export`; run one before trusting `tsc` on route hrefs.
- `EXPO_PUBLIC_*` variables are inlined into the JavaScript bundle. They are
  configuration, never secrets.
