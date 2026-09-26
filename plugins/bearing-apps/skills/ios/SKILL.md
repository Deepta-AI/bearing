---
name: ios
description: 'Conventions for native iOS: Swift 6, SwiftUI, Observation, Swift Concurrency, SwiftPM, XcodeGen, SwiftData, Swift Testing, Fastlane. Use when writing, reviewing or scaffolding "Swift", "SwiftUI" or "iOS" code.'
allowed-tools: Read, Grep, Glob, Skill, Bash(swift build:*), Bash(swift test:*), Bash(swiftlint:*), Bash(swiftformat --lint:*), Bash(xcodebuild -list:*), Bash(xcodebuild test:*), Bash(make:*)
---

# ios

The iOS stack on this standard: Swift 6 language mode (complete strict
concurrency, data races are compile errors) on the Swift 6.3 toolchain and
Xcode 26.6, SwiftUI, `@Observable` view models, async/await with actors and
`MainActor`, SwiftPM for dependencies and for the app's own modules, XcodeGen
so no `.xcodeproj` is committed, URLSession + Codable, Keychain for tokens,
SwiftData for local data, swiftformat + SwiftLint, Swift Testing (`@Test`,
`#expect`) for unit tests and XCTest for UI tests, Fastlane for
TestFlight. Minimum iOS 17.

## Inputs

- Swift files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.swift` files, `project.yml`, xcconfig, the privacy
  manifest or the String Catalog: apply `references/guidelines.md`. Read it
  once per session, then work.
- Reviewing a diff with Swift files: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo ios <Name>`): `templates/` holds the skeleton
  and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy. The
  scaffold fills placeholders in file contents only; `make setup` (or
  `make generate`) renames the two placeholder paths.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Pack skills

`swiftui-pro` (twostraws) covers SwiftUI itself in more detail than this
lane's checklist: deprecated against modern API, view composition,
performance, Human Interface Guidelines and VoiceOver detail. When it is
installed, load it with the Skill tool whenever SwiftUI views are written
or reviewed, after this lane's checklist, and carry its findings into the
reviewer report. This lane still owns architecture, concurrency
isolation, the Keychain, XcodeGen, the privacy manifest and the gate.

- Its core instructions assume iOS 26; the floor here is iOS 17. An iOS
  26 API it proposes goes behind `if #available(iOS 26, *)` or is dropped.
- String Catalog keys stay dotted (`health.title`) until an ADR adopts its
  generated symbol keys.
- Its checks live in nine reference files. If they do not load, say
  "swiftui-pro: references missing" and review from this lane's checklist
  alone. The same applies when it is not installed.

## Layout

```
App/<Name>App.swift          entry point: build the container, show ContentView
App/AppContainer.swift       composition root and the \.container environment key
App/ContentView.swift        screens and views; one file per screen
App/Assets.xcassets          AppIcon, AccentColor
App/PrivacyInfo.xcprivacy    privacy manifest (required-reason APIs, data types)
App/Localizable.xcstrings    String Catalog; every user-facing string
Packages/<Name>Kit/          local package: builds and tests without Xcode
  Sources/Core/              AppError, SecretStore (Keychain), WallClock
  Sources/Networking/        APIClient (URLSession, async, typed errors), Endpoint
  Sources/Features/<F>/      Model, Service, ViewModel per feature
  Tests/{Core,Networking,Features}Tests/
project.yml                  XcodeGen spec; the .xcodeproj is generated and ignored
Config/{Debug,Release}.xcconfig   API_BASE_URL and build settings per configuration
fastlane/                    beta lane (TestFlight); the engineer runs it
Makefile                     the only entry point: help setup generate dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 2, 3 (no new `DispatchQueue`), 4, 5, 7, and no
signing material in the repository. Advisory: the directory layout,
`@Observable` (an `ObservableObject` codebase is not rewritten; new
screens follow rule 1), XcodeGen (a committed `.xcodeproj` stays), the
local package split, the TestFlight lane and the Makefile targets:
propose a switch in an ADR, never inside a feature change. Say which
rule was relaxed and why.

## Rules that matter most

1. State flows down, events flow up. Screens own an `@Observable
   @MainActor` view model in `@State`; no `ObservableObject`, `@Published`
   or `@StateObject` in new code.
2. Every network call is `async`, cancellable, decoded with `Codable`, and
   throws `AppError`. Views start work with `.task`, never an unstructured
   `Task {}` in `body`. Every screen renders loading, error and empty.
3. `MainActor` for UI state, actors for shared mutable state, no
   `DispatchQueue` in new code. `[weak self]` in escaping closures that
   outlive the view.
4. Tokens in the Keychain through `SecretStore`, never `UserDefaults`.
   Configuration through xcconfig into `Info.plist`, read once in the
   container.
5. No force unwraps, `try!` or `as!` outside tests; `fatalError` only in
   the composition root.
6. Dependencies through initialisers and the `\.container` environment key;
   `AppContainer` is the only singleton.
7. Accessibility label and Dynamic Type on every view; strings in the
   String Catalog; a usage string in `project.yml` and a privacy manifest
   entry for every permission.
8. `make check` = swiftformat lint, SwiftLint strict, `swift test` in the
   package, plus `xcodebuild build` where Xcode exists. CI runs the same.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form to run without one.

```
make setup       # brew: xcodegen swiftlint swiftformat fastlane; git hooks
make generate    # project.yml -> <Name>.xcodeproj (also writes Local.xcconfig from .env)
make dev         # generate and open in Xcode
make check       # swiftformat --lint . ; swiftlint --strict ; swift test --package-path Packages/<Name>Kit (plus xcodebuild build on macOS)
make fix         # swiftformat . ; swiftlint --fix
make test        # swift test --package-path Packages/<Name>Kit (no package: xcodebuild test)
make test-ui     # xcodebuild test -scheme <Name> -destination 'platform=iOS Simulator,name=iPhone 17'
fastlane beta    # TestFlight, from a Mac with ASC_* in the environment
```

## Gotchas

- Xcode runs only on macOS. CI needs a runner tagged `macos` (self-hosted
  Mac or a Mac cloud) for `build`, `ui-test` and `publish`; the template
  marks them `allow_failure: true` until one exists. Format, lint and the
  package tests run on the `swift:6.3.3` Linux image.
- Signing never enters the repo: `match` or an App Store Connect API key
  from masked CI variables (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_CONTENT`). The pre-commit hook blocks `.p12`, `.p8`,
  `.mobileprovision`.
- SwiftPM caching: cache `Packages/<Name>Kit/.build` keyed by branch;
  `Package.resolved` is committed once a dependency exists.
- Simulator selection: `SIMULATOR="iPhone 17" make test-ui`; the CI job
  checks `xcrun simctl list devices available` first and fails with the
  list when the name is wrong.
- Swift 6 mode makes a data race a compile error. Fix the isolation (an
  actor, `@MainActor`, a `Sendable` value); `@unchecked Sendable` and
  `nonisolated(unsafe)` need a comment naming what protects the state.
  An existing Swift 5 repository moves one module at a time: turn on
  `-strict-concurrency=complete` first, clear the warnings, then flip the
  module's language mode.
- Swift Testing runs tests in parallel by default. A suite that shares
  state (a `URLProtocol` stub's static handler) is `@Suite(.serialized)`.
  An `#expect` inside a callback on another thread has no test to report
  to; record what the callback saw and assert in the test body.
- `brg-scaffold` does not rename paths: `Packages/__REPO_NAME__Kit` and
  `App/__REPO_NAME__App.swift` keep their placeholder names until
  `make setup` or `make generate` runs the `paths` step.
