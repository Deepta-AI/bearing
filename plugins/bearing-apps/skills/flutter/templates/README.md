# __REPO_NAME__

Flutter app (Android and iOS from one codebase). `make help` lists every
command; `make check` is the gate.

## Run

```
make setup          # flutter pub get (writes pubspec.lock; commit it), android/ and ios/, generated code, git hooks
make dev            # flutter run with config/dev.json on the connected device
make dev FLAVOR=staging
```

`make check` prints one `<gate>: N ... checked` line per gate (`dart
format`, `flutter analyze --fatal-infos`, `flutter test --coverage`) and a
final tally. A gate whose tool is missing prints `SKIPPED` and the tally
fails; `BEARING_ALLOW_SKIP=1 make check` lets a laptop through and is never set
in CI. `make test-integration` needs a device, emulator or desktop target
and is not part of `check`.

## Layout

See `AGENTS.md` and the `flutter` skill for the conventions.
`lib/main.dart` boots, `lib/app.dart` and `lib/router.dart` wire,
`lib/core` holds config, http and logging, `lib/features/<feature>` owns a
domain (model, repository, providers, page), `lib/l10n` holds the strings,
`config/` holds one JSON per flavour, `test/` and `integration_test/`
mirror `lib/`. The Dart package is named `app`, so imports read
`package:app/...`.

## Flavours and configuration

`config/dev.json`, `config/staging.json` and `config/prod.json` are passed
with `--dart-define-from-file`; `lib/core/config.dart` reads and validates
them at boot. The values are compiled into the binary and readable from it:
configuration, never secrets. On the Android emulator the dev API URL is
`http://10.0.2.2:8080`; on the iOS simulator and desktop it is
`http://localhost:8080`; edit `config/dev.json` for your machine.

## Generated code

`*.freezed.dart`, `*.g.dart` and `lib/l10n/generated/` are git-ignored and
written by `make gen` (part of `make setup`). After changing a model or an
ARB file, run `make gen` again.

## Release

```
make build-android FLAVOR=prod      # build/app/outputs/flutter-apk/app-release.apk
make build-ios FLAVOR=prod          # macOS only
make release-android                # prints the fastlane lane; a person runs it
make release-ios                    # prints the fastlane lane; a person runs it
```

CI on Linux runs the gate and builds the Android APK; iOS builds run on a
macOS runner on request. `android/fastlane` and `ios/fastlane` hold the
store lanes; signing keys and service-account files never enter the
repository.
