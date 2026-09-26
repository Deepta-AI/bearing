---
paths:
  - "lib/**/*.dart"
  - "test/**/*.dart"
  - "integration_test/**/*.dart"
---

# Flutter rules (loaded when a .dart file is touched)

- Widgets lay out only: no parsing, no arithmetic on domain values, no
  IO in `build`; a widget file under 200 lines with one public widget.
- Providers own state: `ref.watch` to read, the provider's methods to
  change; `setState` only for ephemeral widget state; no global mutable
  singleton, no `late` that is set from a widget.
- Repositories own IO: every network call goes through one, returns a
  typed model (`freezed`, `fromJson`) and throws a typed exception; no
  `Response`, `Map` or `dynamic` past the repository.
- Every screen renders loading, error with retry, and data
  (`AsyncValue.when`, all three branches).
- No `print` and no `debugPrint` of data; `package:logging` through
  `core/logging.dart`; never a token, body or personal value in a log.
- Navigation through named `go_router` routes; deep-link parameters are
  validated before use and never trusted for authorisation.
- Configuration from `--dart-define-from-file`; secrets only from the API
  after sign-in, stored in secure storage, never in a define or an asset.
- `const` constructors wherever possible; keys on list items; no work in
  `initState` that belongs in a provider; `dispose` everything created.
- Every interactive element has a semantic label, a 48 dp target and a
  visible focus; text respects the system scale.
- Strings through the ARB file and `AppLocalizations`; no user-facing
  literal in a widget.
- Tests: a unit per repository and provider with a fake adapter, a widget
  test per screen covering loading, error and data, pumped with the
  localisation delegates; no real network, no `Future.delayed` waits. A
  bug fix ships with its test. No `// ignore:` without a task id.
