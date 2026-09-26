# iOS review checklist

For each item, either find the concrete failure or write "none found".

## Concurrency and lifetime
- A retain cycle: a closure stored by a long-lived object (a client, a
  timer, a notification observer, a `Task` kept in a property) captures
  `self` strongly; a parent and child view model hold each other.
- UI state mutated off the main actor: a non-`@MainActor` type sets a
  property a view reads; a `nonisolated` or detached task touches a view
  model; `MainActor.assumeIsolated` used to silence a warning.
- A `Task` that is never cancelled: stored in a property without `cancel()`
  in the owner's teardown; a `for await` over a stream with no exit; an
  unstructured `Task {}` created in a view `body` or in `init`.
- `Task.detached` or `DispatchQueue` in new code; `Thread.sleep` or
  `DispatchSemaphore` bridging async code.
- Shared mutable state in a class without an actor, a lock, or
  `@unchecked Sendable` with a comment saying what protects it.
- A module or target left in Swift 5 language mode, or a
  `-strict-concurrency=minimal` override, in a repository on Swift 6.
- A new unit test written in XCTest instead of Swift Testing; a Swift
  Testing suite that mutates shared static state without
  `@Suite(.serialized)`; an `#expect` inside a callback that runs on
  another thread.

## SwiftUI
- `@State` holding something the view does not own (a shared model passed
  in), or a value that must survive the view (use `@Environment` or a model
  owned by the parent); `@State` mutated from another view.
- A `List` or `ForEach` over an array without stable ids (`id: \.self` on
  non-unique values, index-based ids); a list with no `.id` that reorders.
- A screen that renders only the loaded state: no loading indicator, no
  error state with a retry when `isRetryable`, no empty state with a next
  action.
- Fixed `.frame(width:height:)` on text or on containers of text; a
  `.lineLimit(1)` on user content; `.font(.system(size:))` instead of a
  text style; `minimumScaleFactor` used as a layout fix.
- A tappable element without an accessibility label; decorative images not
  hidden; a custom control without traits; colour as the only signal.
- Navigation state in a view model that also holds server data; deep-link
  state not validated before pushing a screen.

## Networking and data
- Force unwrap, `try!`, `as!`, `fatalError` outside tests and the
  composition root; an `Optional` unwrapped with `!` after a check that
  could go stale.
- A `Codable` key mismatch: a struct property renamed without
  `CodingKeys`; a server enum decoded without an `unknown` case; a date
  decoded with the wrong strategy; a number decoded as `Int` that can be
  fractional.
- A request built with string concatenation; a URL from user input not
  validated; a response body logged; a token in a URL or a log line.
- An error swallowed (`try?` on a call whose failure matters) or mapped to
  `AppError.unknown` when a typed case exists; `localizedDescription`
  shown to a user.
- Keychain misuse: a token in `UserDefaults`, `@AppStorage` or a plist; the
  wrong accessibility class; a Keychain call on the main thread during
  launch; the service name not the bundle id.
- A universal link or custom URL scheme handled without checking host,
  path and the signed-in user before acting on it.
- A SwiftData model change without a migration plan; a fetch on the main
  actor that can return thousands of rows without a limit.

## Platform hygiene
- A permission requested without its `NS*UsageDescription` in `project.yml`
  or its entry in `PrivacyInfo.xcprivacy`; a required-reason API added by a
  dependency and not declared.
- A user-facing string hard-coded in a view instead of the String Catalog;
  a string built by concatenation that a translator cannot reorder.
- A new dependency added unasked or unpinned; a binary target without a
  checksum; a `Package.resolved` change with no dependency change.
- A setting changed in Xcode and not in `project.yml`; `Info.plist` or the
  `.xcodeproj` committed.

## Tests
- A bug fix without a reproducing test.
- A test with `sleep`, `XCTWaiter` on a fixed timeout, a real clock, a real
  network or the real Keychain.
- A view model test that does not cover the failure path; a test that
  cannot fail (asserts on its own fixture).

## Hygiene
- `swiftlint:disable` added; a lint rule disabled; a warning silenced with
  `@unchecked Sendable` or `nonisolated(unsafe)` without a comment.
- A public type without a doc comment; a file over 400 lines; a `Utils`
  or `Helpers` file.
- Em dash in a comment or doc.
