# flutter: commands

Read when a make target is missing and the native form is needed.

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
