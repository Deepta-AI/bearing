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
under the role names the web lanes use (`background`, `foreground`,
`primary`, `destructive`, `border`), dark mode and platform variants are
class prefixes instead of branches, and it compiles to `StyleSheet` at
build time so there is no runtime cost. The web lanes are on Tailwind v4,
which has no config file: their tokens are CSS variables in the global
stylesheet. NativeWind 4 still compiles against Tailwind v3, so the two
files share names, not a file; a token changed on one side changes on the
other in the same MR. `StyleSheet` is still right for one-off
animated or measured styles.

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

- `expo-upgrade`: an Expo SDK bump, or replacing a package Expo has
  deprecated (expo-av, AsyncStorage, direct `@react-navigation/*`
  imports). Its version floors win over this lane's pins; the gate after
  it is `make check` then `make doctor`. Its prebuild and cache steps
  apply only where `ios/` and `android/` are committed.
- `expo-router`: native navigation UI (stack headers, modals, form sheets,
  NativeTabs, link previews and menus) and the SDK 56+ rule to import
  from `expo-router/react-navigation`, never `@react-navigation/*`. Rule 5
  still holds. Route files under `app/` are URLs and follow expo-router's
  kebab-case (`app/order-history.tsx`); component files everywhere else
  keep this lane's naming, the component's name.
- `expo-dev-client` is not loaded: its commands are EAS cloud builds, some
  submitting to TestFlight, which the repository settings deny and which
  are the engineer's call. A local dev client comes from `make ios` or
  `make android`.

## Layout

```
app/_layout.tsx                 root providers: QueryClient, SafeArea, Stack
app/<route>.tsx                 expo-router screens; a screen wires hooks to components
src/features/<feature>/api.ts   fetch calls that return Zod-parsed types
src/features/<feature>/schemas.ts  Zod schemas and the types derived from them
src/features/<feature>/hooks.ts    useQuery / useMutation wrappers, query keys
src/features/<feature>/components/ feature screens' building blocks
src/components/                 shared presentational components
src/lib/                        api client, query client, secure store, stores
assets/                         fonts, images, splash; nothing generated
.maestro/                       one flow per user-facing journey
Makefile                        the only entry point: help setup dev check fix test doctor
```

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
- Docs disagree. The API reference and its changelog beat a README line;
  an Accepted ADR beats both. Read the changelog to its newest entry: a
  status, field or limit added there and missing from the body is still
  live. Say which document you followed and correct or flag the stale one.
- A `z.enum` over a server-owned value (status, type) turns one new value
  into a failed page for that customer. Accept every value the docs and
  changelog name, and render an unknown one as a neutral label
  (`.catch()`, or `z.string()` with a known-label map), never a throw.

Paginated lists (`useInfiniteQuery`)
- `getNextPageParam` returns `undefined` when the cursor is null; the list
  calls `fetchNextPage` from `onEndReached` only when `hasNextPage &&
  !isFetchingNextPage` (it fires several times per scroll).
- A failed next page sets `isError` while `data` still holds the pages
  already loaded. Check `data` before `isError`, show the page error as a
  footer with retry (`isFetchNextPageError`), and never replace 60 loaded
  rows with a full-screen error.
- Refetch on focus refetches every loaded page in sequence: a customer 20
  pages deep makes 20 requests on each return to the app. Set `maxPages`,
  or a `staleTime` with a reason, on long histories.
- Keys come from the item id; flatten pages once (`select` or `useMemo`).

Deep links and sessions
- A signed-out customer who opens a link must land on that target after
  sign in. The gate passes the path it blocked (`usePathname` plus params)
  to sign in as a `next` param; sign in accepts `next` only as an in-app
  path (one leading `/`, no `//`, no scheme, not an auth route, ideally
  matched against the routes that may be linked) and `router.replace`s to
  it, else to home.
- A cold-start deep link has no screen under it: export `unstable_settings
  = { initialRouteName: '(tabs)' }` from the group layout so Back returns
  to the tabs instead of closing the app.
- Sign out clears the query cache (`queryClient.clear()`, and any persisted
  cache). Otherwise the next person to sign in on a shared phone sees the
  previous customer's data until the refetch lands.

Writes
- A submit is a `useMutation`; the button is disabled while `isPending`,
  and a failure shows a message with retry.
- A POST that creates something carries an idempotency key generated once
  per user intent (when the form opens or on first submit), kept across
  retries, and replaced only after success. A key made per request does
  not stop the duplicate a timeout-then-retry creates.
- Required choices are required: never default a missing reason or
  selection to a value the customer did not pick.
- Show an action only when the server will accept it (a return window, a
  status): compute it from the data, and map the refusal (422) to copy.

Uploads and media
- Files go to a presigned URL the API issues; the app never holds a
  storage key or signing secret, never builds a bucket URL, and sends the
  server's upload id back, not a key it made up. `Date.now()` in a key
  collides under `Promise.all`.
- Camera photos at `quality: 1` are often over 5 MB. Resize (expo-image-
  manipulator when installed) or lower `quality`, then check the size
  (`asset.fileSize` can be undefined; stat the file) against the server's
  limit before asking for the URL.

Native changes
- A new native module (expo-image-picker, MMKV, anything with a config
  plugin) needs its plugin entry and usage strings in `app.json`; iOS
  terminates the app the first time the camera or library is opened
  without `NSCameraUsageDescription` or `NSPhotoLibraryUsageDescription`.
- With expo-updates and `runtimeVersion: { policy: "appVersion" }`, a new
  native module under an unchanged `version` lets an `eas update` reach
  binaries that lack it: the import throws, at launch when it sits in a
  layout. Bump `version` (or use the `fingerprint` policy) and ship a
  store build before any update that needs it.

Tests that count
- A test of a schema or a URL helper does not test the feature. Test the
  hook with `renderHook` and a fresh `QueryClient` (`retry: false`) with
  the `api.ts` module mocked (next page requested with the cursor, stops
  at null), and the screen with Testing Library (rows render, an invalid
  id shows the error and calls nothing).

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
