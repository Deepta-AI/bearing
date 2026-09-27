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
- A DTO whose property names do not match the JSON the contract (API
  doc, README note, sample payload) describes: with `ignoreUnknownKeys`
  a renamed field is silently dropped, so a required property throws
  `MissingFieldException` on every real response (and a `runCatching`
  hides it) while a defaulted one shows the default. Tests with a fake
  API that returns DTOs never exercise this; compare each
  `@SerialName` against the documented payload.

## Security
- An exported activity, service, receiver or provider beyond the launcher
  and link handlers, or one with `exported="true"` and no permission.
- An intent extra, deep-link parameter or `Uri` used without validation.
  `lastPathSegment` is decoded; with `@Path(encoded = true)` a `/` or `?`
  in it reshapes an authenticated request (Retrofit itself rejects only
  `.` and `..` segments). `!!` on intent data crashes on an explicit
  intent with no data, which any app can send to an exported activity.
- Intent filters: a custom scheme with no host, `pathPrefix` that also
  matches `/ordersX`, `autoVerify` without `assetlinks.json` on that host
  (release signing SHA-256), or a link that reaches users through a
  redirect (email click tracking) so the tapped host is not the filtered
  one. Asking to un-export a link handler is the wrong fix.
- A link handler with `launchMode` `singleTop` or `singleTask` (or a
  `FLAG_ACTIVITY_SINGLE_TOP` launch) that reads `intent` only in
  `onCreate`: a second link while it is alive arrives in `onNewIntent`
  and the screen keeps showing the first target.
- A deep link or notification that opens a screen on a cold start without
  restoring the session or offering sign in; a failure (401, 404,
  offline) that leaves a spinner with no error state.
- A token in plaintext in DataStore or `SharedPreferences`, a log line, a
  crash breadcrumb or a `BuildConfig` field; new `EncryptedSharedPreferences`
  or security-crypto use (deprecated; Tink with a Keystore-wrapped keyset).
- `targetSdk` lowered, or below Google Play's current target API floor
  (it rises each August; confirm the level on the Play policy page). A
  lower target to dodge edge-to-edge is fixed with insets on the screen.
- Session changes: rotated refresh token not persisted; refresh not single
  flight; any refresh failure (offline, 5xx) treated as signed out; sign
  out that does not serialize with refresh, waits on the network, leaves Room or
  other per-user data, or lets an in-flight fetch write it back; key loss
  that clears the ciphertext but not the keyset.
- Cleartext allowed in `network_security_config.xml`; logging interceptor
  at `HEADERS` or `BODY` in a non-debug path (it prints tokens from auth
  responses and the `Authorization` header). Report it even when it
  predates the branch, marked as pre-existing, when the branch's flow
  sends tokens through it.
- A new endpoint the API contract does not document: ask whether the
  server checks that the resource belongs to the caller.
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
