# Android review checklist

For each item, either find the concrete failure or write "none found".

## Coroutines and lifecycle
- `GlobalScope`, a `CoroutineScope(...)` built by hand with no owner, or a
  coroutine launched in `onCreate` that is never cancelled.
- Blocking on the main thread: `runBlocking`, `Thread.sleep`, a Room query
  or file read outside `withContext(io)`.
- A Flow collected without a lifecycle: bare `collect` in an Activity or
  Fragment, `collectAsState()` where `collectAsStateWithLifecycle()` fits.
- A `MutableStateFlow` or `MutableSharedFlow` exposed from a ViewModel.
- `Dispatchers.IO` named inline instead of injected.
- `runCatching` or `catch (e: Exception)` that swallows
  `CancellationException`.

## Architecture
- A Retrofit DTO or `Response<T>` reaching a ViewModel or composable.
- A ViewModel holding a `Context`, `Activity`, `View` or `Fragment`.
- Derived state stored in a field instead of computed from `UiState`.
- LiveData in a new file; a `Channel` of events where state would do.
- Business logic in a composable or an Activity.

## Data
- A Room query on the main thread; multi-statement writes without
  `@Transaction`; a schema change without a migration and its test.
- Room bypassed: the UI observing a network call directly.
- `SELECT *` mapped to a partial entity; a missing index on a filter column.
- `Json` created per call; `ignoreUnknownKeys` missing on a public API.

## Security
- An exported activity, service, receiver or provider beyond the launcher,
  or one with `exported="true"` and no permission.
- An intent extra, deep-link parameter or `Uri` used without validation.
- A token in plaintext in DataStore or `SharedPreferences`, a log line, a
  crash breadcrumb or a `BuildConfig` field; new `EncryptedSharedPreferences`
  or security-crypto use (deprecated; Tink with a Keystore-wrapped keyset).
- `targetSdk` below 36 (Google Play's floor for new apps and updates).
- Cleartext allowed in `network_security_config.xml`; logging interceptor
  at `HEADERS` or `BODY` in a non-debug path.
- A keystore, password, `local.properties` or `google-services.json` added.
- A package-wide keep rule (`-keep class x.** { *; }`) or a rule for a
  library that ships its own (kotlinx, Retrofit, OkHttp, AndroidX).
- WebView with `javaScriptEnabled` and an unvalidated URL.

## Compose
- Side effects in composition (a network call, navigation, analytics or
  logging outside `LaunchedEffect`/`DisposableEffect`).
- `remember` with missing or wrong keys; `LaunchedEffect(Unit)` that depends
  on a value that changes.
- State hoisted too high or too low; a Screen that owns a ViewModel.
- An unstable parameter (a `List`, a lambda capturing mutable state) causing
  recomposition of a whole list; a `LazyColumn` without keys.
- A hard-coded string, colour or dimension; a missing `contentDescription`.
- A `Modifier` parameter missing, not last, or not applied to the root.

## Tests
- A bug fix without a reproducing test.
- A ViewModel test without `Dispatchers.setMain`; a test that sleeps or
  hits the network; a Turbine block that never `awaitItem()`s.
- A Compose test that navigates the whole app for a single screen check.
- A migration without a `MigrationTestHelper` test.

## Build and hygiene
- A literal dependency coordinate outside `libs.versions.toml`; a version
  bumped unasked.
- `@Suppress` or `@file:Suppress` added, a detekt or lint rule disabled,
  a lint baseline grown.
- `!!` outside tests; `lateinit` for a constructor parameter.
- An em dash in a comment, string or doc.
