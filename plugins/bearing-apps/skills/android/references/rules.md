---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "**/*.java"
---

# Android rules (loaded when a Kotlin, Gradle or Java file is touched)

- One `UiState` per ViewModel, exposed as a single `StateFlow`; the mutable
  flow is private. No LiveData in new code.
- Coroutines in `viewModelScope` or a lifecycle scope; `GlobalScope` never.
  Dispatchers injected by qualifier. Never catch `CancellationException`.
- Room is the only local source of truth; the repository merges network and
  Room and returns domain types. DTOs never reach the UI.
- Tokens only as Tink ciphertext with a Keystore-wrapped keyset; never
  plaintext in DataStore or prefs, never a log, no `EncryptedSharedPreferences`.
- No exported component beyond the launcher without a permission. Validate
  every deep link and intent extra before use.
- Compose: `Route` collects, `Screen` is stateless; no side effects in
  composition; `remember` and `LaunchedEffect` keys name every input;
  strings and dimensions from resources or the theme.
- Versions live only in `gradle/libs.versions.toml`; no literal coordinates.
- Unit tests: JUnit Jupiter (JUnit 6) + Turbine with a fake repository and a test
  dispatcher. Instrumented: JUnit 4 rules. No sleeps, no network.
- Java files: `final` fields, records or AutoValue, no raw types, no
  `Optional` fields, `Executor`s injected.
