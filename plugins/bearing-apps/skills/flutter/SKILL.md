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

When the Flutter team's agent-plugins pack is installed, load its skills for
layout overflow, deep-link platform setup and widget-test mechanics; when it
is not, do the job from this lane's references and name the missing skill.
Detail: references/pack-skills.md

## Layout

`lib/main.dart` boots only; `lib/features/<f>/` holds the model, repository,
provider and page; IO happens only in the repository. Detail:
references/layout.md

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
that the change touches, in new code and in the code it relies on. Detail:
references/traps.md

## Verifying

Find the SDK before saying it is missing, run tests under a time limit, run
the gate on the untouched base first, and separate what ran from what did
not in the final message. Detail: references/verifying.md

## Commands

Each `make` target is used when the Makefile has it; the native form is in
references/commands.md.

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
