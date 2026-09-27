# Pantry for Android

The Pantry grocery app: sign in, browse your past orders, reorder. Live on
Google Play since June 2026 (about 40k monthly users).

## Build

```
make check    # ktlint, detekt, Android lint, unit tests, assembleDebug
make test     # unit tests only
```

JDK 17 and the Android SDK (compileSdk 36) are required. `API_BASE_URL` is
read from a Gradle property or the environment.

## Layout

- `ui/<feature>`: Compose screens and their ViewModels
- `domain/<feature>`: models and repository interfaces
- `data/<feature>`: repository implementations, Room, DataStore
- `data/network`: Retrofit service and DTOs
- `docs/adr`: decisions; `docs/api.md`: the backend contract we rely on

## Sessions

The session is kept in memory only (`SessionHolder`), so users sign in again
whenever the process dies. Plan: persist it with EncryptedSharedPreferences
(androidx.security:security-crypto).
