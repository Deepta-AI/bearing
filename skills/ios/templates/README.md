# __REPO_NAME__

iOS app. `make help` lists every command; `make check` is the gate.

## Run

```
cp .env.example .env        # API_BASE_URL, DEVELOPMENT_TEAM
make setup                  # brew: xcodegen swiftlint swiftformat fastlane; git hooks
make generate               # project.yml -> __REPO_NAME__.xcodeproj and App/Info.plist (never committed)
make dev                    # opens the project; pick a simulator and run
```

`.xcode-version` names the Xcode release the project and CI runners use.

`make check` runs format, lint, the package tests (`swift test`, no Xcode
needed) and the simulator build, printing one `<gate>: N ... checked` line
each and a final tally. On Linux or without Xcode the build gate prints
`SKIPPED` and the tally fails; `BEARING_ALLOW_SKIP=1 make check` lets such a
machine through and is never set in CI. `make test-ui` runs the simulator
tests on `SIMULATOR` or, when unset, the first available iPhone; it fails
with the `xcrun simctl` command to run when none is installed. It is not
part of `check`.

## Layout

See `AGENTS.md` and the `ios` skill for the conventions. `App/` is the
Xcode target (entry point, views, container, assets, privacy manifest).
`Packages/__REPO_NAME__Kit` holds `Core` (errors, Keychain, clock),
`Networking` (URLSession client, endpoints) and `Features` (models,
services, view models), each with a test target. `project.yml` describes the
Xcode project and generates `App/Info.plist` (git-ignored, rewritten on every
`make generate`); `Config/*.xcconfig` carry per-configuration settings;
`fastlane/` carries the TestFlight lane.

## Rename the bundle id

The id is `__ORG_ID__.__REPO_SLUG__` in `project.yml` and
`fastlane/Appfile`. Change both, run `make generate`, and register the new
id in App Store Connect before the first `fastlane beta`.

## Signing in CI

Nothing signing-related is committed. Set masked, protected CI variables:
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (the `.p8` base64-encoded)
for App Store Connect, plus `MATCH_GIT_URL` and `MATCH_PASSWORD` if the team
uses `match`. The `publish` job runs `fastlane beta` on a runner tagged
`macos`; until such a runner exists the macOS jobs are `allow_failure`.
