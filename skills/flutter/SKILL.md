---
name: flutter
description: 'Conventions for Flutter: Dart 3, Riverpod, go_router, dio, freezed, ARB localisation, flavours, flutter_test, integration_test, fastlane. Use when writing, reviewing or scaffolding "Flutter", "Dart" or "Riverpod" code.'
allowed-tools: Read, Grep, Glob, Skill, Bash(flutter analyze:*), Bash(flutter test:*), Bash(flutter pub:*), Bash(dart format:*), Bash(dart run:*), Bash(make:*)
---

# flutter

The Flutter stack on this standard: Flutter 3.35 or newer on Dart 3,
`flutter_riverpod` for state (Bloc is the `tech-decision` alternative under
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
  with this skill. `new-repo` and `ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.dart` files: apply `references/guidelines.md`. Read
  it once per session, then work.
- Reviewing a diff with Dart files: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo flutter-app <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` copies them. Do not hand-copy.
- Generating CI (`ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Pack skills

The Flutter team's agent-plugins pack is weaker than this lane at
conventions and stronger at three narrow jobs. When one of the three is
installed, load it with the Skill tool for that job; when it is not, do
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

Not loaded here, because this lane is stronger at the same job:
`flutter-apply-architecture-best-practices` prescribes `ChangeNotifier`
view models with `provider` or `get_it` (use it only in a repository
already built that way, under "On a foreign layout");
`flutter-setup-localization` uses the deprecated synthetic `flutter_gen`
package, while `l10n.yaml` here writes to `lib/l10n/generated`;
`flutter-add-integration-test` puts `enableFlutterDriverExtension` in the
app entry point for MCP driving, while the smoke flow here runs under
`flutter test` and `lib/main.dart` stays boot only;
`dart-run-static-analysis` is a subset of `make check`.

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
