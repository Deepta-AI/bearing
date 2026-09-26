---
paths:
  - "**/*.swift"
---

# iOS rules (loaded when a .swift file is touched)

- State flows down, events flow up. Screens own an `@Observable` view
  model in `@State`; children take values and closures. No
  `ObservableObject`, `@Published`, `@StateObject` in new code.
- UI state is `@MainActor`; shared mutable state is an actor; no
  `DispatchQueue`, no `Combine` for new flows. Every network call is `async`,
  cancellable, decoded with `Codable`, and throws `AppError`.
- Views start work with `.task`, never an unstructured `Task {}` in `body`.
  Every screen renders loading, error (with retry when retryable) and empty.
- Tokens and secrets in the Keychain through `SecretStore`; never
  `UserDefaults`. Config from `Info.plist` via xcconfig, never hard-coded.
- No `!` unwraps, `try!`, `as!` outside tests; no `fatalError` outside the
  composition root. `[weak self]` in every escaping closure that outlives the
  view.
- Dependencies through initialisers and the `\.container` environment key;
  the `AppContainer` is the only singleton.
- Every view: accessibility label or identifier, Dynamic Type (no fixed
  frames on text), strings in the String Catalog with a dotted key.
- Every permission: a usage string in `project.yml` and a privacy manifest
  entry. Universal links validated before navigation.
- Tests: `swift test` in the package for logic, `URLProtocol` stubs for
  networking, `FixedClock` for time, no sleeps, no network, no real Keychain.
- No `swiftlint:disable` without a task id and a reason on the same line.
