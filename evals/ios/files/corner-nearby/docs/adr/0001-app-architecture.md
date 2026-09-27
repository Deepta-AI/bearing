# 1. App architecture

Status: Accepted (2026-03-02)

## Decision

- XcodeGen `project.yml` is the project; nothing is changed in Xcode's
  editor.
- Logic lives in the local package `Packages/CornerKit` so it is built and
  tested on the Linux CI runner with `swift test`. Apple-only frameworks
  (SwiftUI, UIKit, CoreLocation, PhotosUI, SwiftData) are used only in
  `App/`, behind a protocol defined in the package when a feature needs
  them.
- One feature folder per feature under `Features/`: model, service
  protocol plus remote implementation, view model.
- View models are `@Observable @MainActor final class`, own a `State` enum
  with loading, loaded, empty and failed, and are tested with fakes.
- All requests go through `APIClient`, which adds the token from
  `SecretStore` (Keychain) and maps errors to `AppError`.

## Consequences

The package cannot see `CLLocationManager` or `UIImage`; the app target
adapts them to package protocols.
