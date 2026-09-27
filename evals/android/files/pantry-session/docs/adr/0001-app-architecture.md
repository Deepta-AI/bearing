# ADR 0001: App architecture

Status: Accepted (2026-03-02)

## Decision

- Kotlin, Jetpack Compose, Material 3, Hilt, coroutines and Flow.
- Each screen has one ViewModel exposing one `UiState` through a single
  `StateFlow`; the mutable flow stays private.
- Room is the only local source of truth. Repositories merge network and
  Room and return domain types; Retrofit DTOs never leave `data/`.
- Coroutines run in `viewModelScope` or an injected application scope.
  Dispatchers are injected through the qualifiers in `di/CoroutinesModule.kt`.
- Every dependency version lives in `gradle/libs.versions.toml`.
