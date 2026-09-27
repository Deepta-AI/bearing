---
name: flutter
description: 'Conventions for Flutter: Dart 3, Riverpod, go_router, dio, freezed, ARB localisation, flavours, flutter_test, integration_test, fastlane. Use when writing, reviewing or scaffolding "Flutter", "Dart" or "Riverpod" code.'
allowed-tools: Read, Grep, Glob, Skill, Bash(flutter analyze:*), Bash(flutter test:*), Bash(flutter pub:*), Bash(dart format:*), Bash(dart run:*), Bash(make:*)
---

# flutter

The Flutter stack on this standard: Flutter 3.35 or newer on Dart 3,
`flutter_riverpod` for state (Bloc is the `bearing:tech-decision` alternative under
the mobile key; choose it when the team already thinks in events and
states), `go_router` for navigation, `dio` with request-id, logging and
retry interceptors, `freezed` plus `json_serializable` models, configuration
by `--dart-define-from-file` (one JSON per flavour: dev, staging, prod),
`flutter_localizations` with ARB files, `flutter_lints` with a strict
`analysis_options.yaml` (`very_good_analysis` is the optional stricter
set), `flutter_test` units and widgets, one `integration_test` smoke, and
fastlane lanes for both stores as text templates.

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.dart` files: apply `references/guidelines.md`. Read
  it once per session, then work.
- Reviewing a diff with Dart files: apply `references/review-checklist.md`
  and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
  The failure scenario is the user-visible effect, traced to the end: a
  throw skips every line after it in that function (a `getToken` that
  throws before `onMessageOpenedApp.listen` means taps never navigate),
  and an unawaited `Future` sends that error to the zone, not to a log.
  "X is outside the try" is the smell; what the user loses is the finding.
  Say which findings block the merge, and attribute gate failures that
  already exist on the base branch to the base, not to the diff.
- Scaffolding (`new-repo flutter-app <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Pack skills

The Flutter team's agent-plugins pack covers three narrow jobs that this
lane uses it for. When one of the three is installed, load it with the Skill tool for that job; when it is not, do
the job from this lane's references and name the missing skill.

- `flutter-fix-layout-issues`: a RenderFlex overflow, an unbounded height
  or width, or an `Expanded` or `Positioned` in the wrong parent.
- `flutter-setup-declarative-routing`: the platform half of deep links
  (Android intent filter and assetlinks.json, iOS associated domains and
  apple-app-site-association). Routes stay named and parameters are
  validated; ignore its string-path `context.go` examples.
- `flutter-add-widget-test`: `WidgetTester` mechanics (finders, `pump`
  against `pumpAndSettle`, scrolling a lazy list). This lane still decides
  what a screen test covers: loading, error and data, inside a
  `ProviderScope` with overrides and the localisation delegates.

Not loaded here: `flutter-apply-architecture-best-practices`
(`ChangeNotifier` view models; only for a repository already built that
way), `flutter-setup-localization` (deprecated synthetic `flutter_gen`),
`flutter-add-integration-test` (puts a driver extension in the entry
point) and `dart-run-static-analysis` (a subset of `make check`).

## Layout

```
lib/main.dart                     boot only: config check, logging, ProviderScope, runApp
lib/app.dart                      MaterialApp.router: theme, l10n delegates, router
lib/router.dart                   GoRouter: routes, error page; names, never string paths
lib/core/config.dart              AppConfig from dart-define; validated at boot
lib/core/http.dart                dio factory plus request-id, logging, retry interceptors
lib/core/logging.dart             package:logging routed to dart:developer; no print
lib/features/<f>/<f>.dart         freezed model with fromJson
lib/features/<f>/<f>_repository.dart   the only place IO happens; typed results, typed errors
lib/features/<f>/<f>_provider.dart     Riverpod providers: repository, async state
lib/features/<f>/<f>_page.dart         ConsumerWidget: layout only; loading, error, data
lib/l10n/app_en.arb               strings; generated code lands in lib/l10n/generated
config/{dev,staging,prod}.json    flavour values for --dart-define-from-file; no secrets
test/, integration_test/          mirrors lib/; one smoke flow in integration_test
android/fastlane, ios/fastlane    store lanes; run by a person, printed by the agent
Makefile                          the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1, 2, 3, 5, 6 and 7. Advisory: the directory
layout, Riverpod (a Bloc or Provider app keeps its own state shape),
go_router (Navigator 2 or auto_route stay), dio (http or chopper stay),
dart-define (an existing `flutter_dotenv` setup stays until an ADR) and
the Makefile targets: use what the repository already has; propose a
switch in an ADR, never inside a feature change. Say which rule was
relaxed and why.

## Rules that matter most

1. Widgets lay out; they hold no business logic and no IO. A `build`
   method that parses JSON, computes a total or calls the network is a
   finding.
2. Providers own state. Screen state lives in a Riverpod provider
   (`FutureProvider`, `Notifier`), read with `ref.watch`, changed through
   the provider; `setState` only for ephemeral widget state (a toggle, a
   text field). Never a global mutable singleton.
3. Repositories own IO. Every network call goes through a repository that
   returns a typed model and throws a typed exception; a `Response` or a
   `Map` never crosses into a provider or a widget.
4. Every screen renders loading, error (with retry) and data. `AsyncValue`
   `when` with all three branches; an error branch that shows nothing is a
   finding.
5. No `print`; `package:logging` through `lib/core/logging.dart`. Never log
   a token, a body or personal data.
6. Accessibility: every interactive element has a semantic label
   (`Tooltip`, `Semantics`, or visible text), touch targets are at least
   48 dp, text scales with the system setting, contrast passes.
7. `const` constructors wherever the tree allows; `flutter analyze
   --fatal-infos` enforces it. A widget rebuilt on every frame without a
   reason is a finding.
8. `make check` = `dart format` check, `flutter analyze --fatal-infos`,
   `flutter test --coverage`. CI runs the same target and builds the
   Android APK on Linux; iOS builds need a macOS runner.
9. The repository's own documents outrank this lane: read `docs/adr/`,
   the API document and the README before writing, and when two of them
   disagree (a stale README against an API changelog) follow the newer
   contract and say so. A new package needs whatever the ADRs require
   first; `dart:math` `Random.secure()` makes an idempotency key without
   one.

## Traps a strong generalist still ships

Each of these passes a read-through and fails on a phone. Check every one
that the change touches, in new code and in the code it relies on.

Writes the user triggers (add, reorder, pay, toggle):

- Read the retry interceptor before adding a write. One that retries
  every method on a timeout or 5xx repeats a POST the server already
  committed: the items go in twice. Limit automatic retry to idempotent
  methods (the skeleton retries GET, HEAD and OPTIONS) or to requests
  carrying an idempotency key,
  and name the existing calls that were exposed (fix them or say so).
- An idempotency key belongs to one user intent, not one request. Make
  it when the user starts the action; reuse it for every automatic retry
  and for the user's own retry after an unknown outcome (timeout,
  connection error, 5xx); drop it only on a definite answer (2xx or 4xx).
  Keep it in state that outlives the row: an `autoDispose` family
  provider disposed when the row scrolls away loses it.
- Double taps: the control is disabled while its request is in flight,
  keyed by the item, and a second tap is ignored, not queued.
- After every `await` the widget may be gone: `if (!context.mounted)
  return;` before using `context`, `if (!mounted) return;` before
  `setState`, and `ref.mounted` in a Riverpod 3 notifier before setting
  `state`.
- Optimistic UI (a switch flipped before its PUT) rolls back and tells
  the user when the write fails; otherwise the screen shows a setting the
  server does not hold.
- Show what the server actually did: a partial success (some items
  unavailable) names what was left out, and so does a total miss (nothing
  added still lists the items by name); a plain "done" on every 200
  hides it.

Lists and values:

- Paginated endpoints: follow the cursor until it is null; raising
  `limit` past the documented cap is not paging. One page request in
  flight at a time (scroll fires many events), pages appended once, an
  error on page n keeps the loaded pages and offers a retry at the end,
  refresh resets the cursor and replaces the list. Test page two and the
  end.
- A timestamp ending in `Z` parses to a UTC `DateTime`, and `DateFormat`
  prints it in UTC: call `.toLocal()` first, or an order placed at 18:42Z
  shows the previous day in India.
- Money is integer minor units plus a currency code, formatted by the
  repository's helper or `NumberFormat.simpleCurrency`; never a `double`
  and never `toStringAsFixed`.
- Enum-like server values (`out_for_delivery`) map to translated labels
  with a fallback for an unknown value; never a raw value on screen.
- The other way, a Dart enum's `.name` is not a wire value:
  `TargetPlatform.iOS.name` is `iOS` where an API may want `ios`. Map to
  the documented strings explicitly and check each one against the API
  document.

Side effects and lifecycle:

- `build` runs on every rebuild. Registering, subscribing, posting,
  navigating or starting a `Future` there (including
  `ref.read(x).start()`) repeats it and stacks listeners. Start once: in
  `main`, in a provider body with `ref.onDispose` cancelling the
  subscription, or in `initState` with `dispose`. An unawaited `Future`
  sends its error nowhere.
- `catchError((_) {})` or an empty `catch` turns every failure into an
  endless spinner; an error needs a state and a retry.

Push notifications (`firebase_messaging`):

- Three tap paths: `getInitialMessage` (cold start from terminated),
  `onMessageOpenedApp` (background), `onMessage` (foreground, where the
  system shows no banner by itself). Handling one loses the others.
- `getToken` can return null or throw (iOS before the APNs token exists,
  no Play services, offline): guard it, keep it inside the error
  handling, and never post a null token. Listen to `onTokenRefresh` and
  register again; unregister on sign-out so the next account on the
  device does not get this user's updates. The token addresses pushes to
  the device: never log it.
- The background handler is a top-level or static function annotated
  `@pragma('vm:entry-point')`. Without the annotation it works in debug
  and can be stripped from release builds; an anonymous closure throws.
- It runs in its own isolate: no `ProviderScope`, no logging that `main`
  configured, no memory shared with the app. It re-initialises what it
  uses and writes anything it must record to storage or the server; a
  handler that only logs does nothing, whatever its comment says.
- `Firebase.initializeApp()` needs `options:` (`firebase_options.dart`)
  or the platform files (`google-services.json`,
  `GoogleService-Info.plist`). With neither in the repository it throws
  before `runApp`, so the app never draws a frame.
- The payload is untrusted input: read the documented keys, validate the
  id, navigate by route name. `router.go(payload['link'])` both misses
  the real key and lets a payload open any path.
- The permission prompt comes when the user sees its value (and as the
  project's decision records say); Android 13 and later also need
  `POST_NOTIFICATIONS` in the manifest.
- A shared secret in a define, an asset, `.env` or secure storage ships
  in the binary and is extractable; once committed it is leaked: rotate
  it and authenticate with the user's session instead. Obfuscation and
  moving it are not fixes.

Tests:

- `testWidgets` runs on a fake clock: `await Future.delayed(...)` in the
  body never completes and hangs the whole suite (so `make check` never
  finishes). Use `pump`, `pumpAndSettle`, or `tester.runAsync` for real
  IO. `pumpAndSettle` never settles while a `CircularProgressIndicator`
  spins; assert the loading branch after a single `pump`.
- Plugins have no platform side under `flutter test`:
  `FirebaseMessaging.instance` in a widget test throws. Put the plugin
  behind a provider and override it.
- Cover the branches that fail in production: error with retry, empty,
  the failed write, page two, the double tap.

## Verifying

- Find the SDK before saying it is missing: `command -v flutter`, then
  `~/flutter/bin/flutter`, `.fvm/flutter_sdk` or `fvm flutter`. Report
  the version that ran.
- Resolve offline (`flutter pub get --offline`). When a pinned package is
  not cached, do not edit `pubspec.yaml` to make it resolve; test on a
  copy in your own scratch folder with `dependency_overrides` and report
  it as that ("tests pass on a copy with X overridden"), never as "make
  check passes". Nothing outside the repository and your scratch folder
  changes.
- Run tests under a time limit (`timeout 300 flutter test`) so a hanging
  test is a finding, not a stuck session. Stop only processes you started,
  by their PID; never `pkill` or `killall` by name or pattern, which ends
  other sessions' `flutter` runs on the same machine.
- Run the gate on the untouched base first. What fails there is the
  base's: report it as pre-existing and leave it alone (no reformatting
  of files the change does not touch, no edits to unrelated doc
  comments) unless the user asked for it; a separate change fixes it.
  The files you wrote must pass format and analyze on their own.
- The final message separates what ran (where, with what result) from
  what did not, and lists risks found but left alone.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form to run without one.

```
make setup            # flutter pub get, platform folders, gen-l10n, build_runner, git hooks
make dev              # flutter run --dart-define-from-file=config/dev.json
make check            # dart format --set-exit-if-changed ; flutter analyze --fatal-infos ; flutter test --coverage
make fix              # dart format ; dart fix --apply
make gen              # dart run build_runner build ; flutter gen-l10n
make test-integration # flutter test integration_test (needs a device or desktop target)
make build-android    # flutter build apk --dart-define-from-file=config/prod.json
make build-ios        # flutter build ipa (macOS only)
make release-android  # prints the fastlane command; a person runs it
```

## Gotchas

- The pubspec `name` is `app` (a Dart package name must be an identifier),
  so imports are `package:app/...`; the repository name lives in the
  README and the store listings.
- `*.freezed.dart`, `*.g.dart` and `lib/l10n/generated/` are generated and
  git-ignored: `make setup` (or `make gen`) writes them, and `flutter
  analyze` fails with "URI has not been generated" until it runs.
- `android/` and `ios/` are created by `flutter create .` inside `make
  setup`, with `--org` from the scaffold; they are committed after the
  first setup. Fastlane files are copied in before that and survive it.
- `--dart-define-from-file` values are compile-time constants baked into
  the binary and readable from it: configuration, never secrets. Secrets
  come from the API after sign-in and live in `flutter_secure_storage`.
- The tall-style formatter (Dart 3.7 and later) manages trailing commas.
  `analysis_options.yaml` sets `formatter: trailing_commas: preserve` so
  `dart format` keeps the commas `require_trailing_commas` asks for;
  without it the two can disagree under `--fatal-infos`.
- `intl` is pinned by `flutter_localizations`; the pubspec says `any` on
  purpose so `pub get` resolves to the SDK's version.
- Riverpod 3 retries a failing provider by itself with backoff (up to ten
  times). `healthProvider` sets `retry` to null because dio already
  retries transport failures and the page owns the button; keep the
  default where a transient failure should heal quietly.
- `integration_test` needs a device, an emulator or a desktop target
  (`-d linux` after `flutter config --enable-linux-desktop`); it is a
  manual target and a CI job with an emulator, never part of `check`.
