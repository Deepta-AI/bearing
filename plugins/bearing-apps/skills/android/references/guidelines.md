# Android guidelines

Kotlin first. The final section lists what changes when the repository is
Java. Everything else holds for both.

## Project shape

- One `app` module until a second team or a measured build-time problem
  justifies feature modules. When splitting, split by feature (`:feature:pay`),
  never by layer (`:data`, `:ui`).
- Packages by feature inside a module: `ui/<feature>`, `domain/<feature>`,
  `data/<feature>`. `domain` has no Android imports.
- `App.kt` carries `@HiltAndroidApp` and nothing else. `MainActivity` sets
  content and owns no state.
- Every version is pinned once in `gradle/libs.versions.toml`. A module's
  `build.gradle.kts` references `libs.*`, never a literal coordinate.
- `gradle.properties` sets `org.gradle.jvmargs`, the configuration cache and
  `android.nonTransitiveRClass=true`. Do not change these per machine; use
  `~/.gradle/gradle.properties` for local overrides.

## Architecture

- Unidirectional data flow. A ViewModel exposes one `UiState` (a sealed
  interface: `Loading`, `Ready(...)`, `Error(...)`) through a single
  `StateFlow`. `MutableStateFlow` is private; the public property is
  `asStateFlow()` or `stateIn(viewModelScope, WhileSubscribed(5_000), initial)`.
- The UI sends events by calling ViewModel functions. No `Channel` of events
  unless a one-shot effect (navigation, snackbar) genuinely cannot live in
  state; if it must, consume it and clear it in state.
- No LiveData in new code. Existing LiveData is converted when the file is
  touched for another reason.
- A ViewModel never holds an `Activity`, `Fragment`, `View` or
  `Context`. Inject `@ApplicationContext` only into data-layer classes.
- The repository is the single door to data: it merges Room and network and
  returns domain types. Room is the only local source of truth; the UI
  observes Room through the repository and never a network response.
- Retrofit DTOs are `@Serializable` classes under `data/network` and are mapped
  to domain types in the repository. They never reach a ViewModel.
- DataStore for preferences (typed keys in one file per feature). Never for
  tokens, never for anything you would not print in a bug report.

## Coroutines and Flow

- Scopes: `viewModelScope` in ViewModels, `lifecycleScope` or
  `repeatOnLifecycle` in Android components, an injected application scope
  for work that outlives a screen. `GlobalScope` is a finding.
- Dispatchers are injected through qualifiers (`@IoDispatcher`,
  `@DefaultDispatcher`); `Dispatchers.IO` appears only in the Hilt module
  that provides it. Tests replace it with a `TestDispatcher`.
- Every suspend function that does I/O switches with `withContext(io)`; the
  caller does not know or care which thread it lands on.
- Never catch `CancellationException`. `runCatching` catches it, so any
  `runCatching` is followed by `.onFailure { if (it is CancellationException)
  throw it }`.
- Collect in the UI with `collectAsStateWithLifecycle()`; in an Activity or
  Fragment with `repeatOnLifecycle(STARTED)`. A bare `collect` in `onCreate` is
  a leak.
- Flows are cold and pure; side effects belong in `onEach` next to the
  collection, not inside a `map`.

## Compose

- A screen is two functions: `<Feature>Route` (gets the ViewModel, collects
  state, passes callbacks) and `<Feature>Screen(state, onX, modifier)` which
  is stateless and previewable. Only the Screen gets a `@Preview`.
- State hoisted to the lowest common owner. `remember` keys name every input
  the value depends on; `rememberSaveable` for anything that must survive
  process death.
- No side effects in composition. Network, analytics, navigation and
  logging run in `LaunchedEffect(keys)`, `DisposableEffect` or a callback.
  `LaunchedEffect(Unit)` is allowed only for one-shot work on first show.
- `Modifier` is the last parameter with a default; every public composable
  accepts one and applies it to the root node.
- Every string, colour and dimension comes from resources or
  `MaterialTheme`. A literal `16.dp` in a screen is acceptable only for
  one-off layout spacing; a literal string never is.
- Every image and icon has a `contentDescription` (or `null` when purely
  decorative, with a comment). Interactive nodes carry a `testTag` when a
  test needs them.
- Lists use `LazyColumn` with stable `key`s; a `Column` in a `verticalScroll`
  for more than a screen of items is a finding.
- Skippability: state classes are immutable (`val`, immutable collections
  or `@Immutable`). Run the Compose compiler metrics before a performance
  claim, not after.

## Data

- Room: entities under `data/<feature>`, one `AppDatabase`, migrations in
  code with a test for each (`MigrationTestHelper`), exported schemas
  committed under `app/schemas/`. Multi-statement writes are `@Transaction`.
  Queries return `Flow<List<T>>` for observed data and are never called on
  the main thread (Room enforces it; keep it enforced).
- Network: one `OkHttpClient`, one `Retrofit`, `Json { ignoreUnknownKeys =
  true }`. Logging interceptor at `BASIC` in debug only; `HEADERS` or `BODY`
  would log tokens. Timeouts set explicitly. Certificate pinning on money
  paths, with a rotation plan written before the pin ships.
- Auth: tokens encrypted with a Tink AEAD (`AesGcmKeyManager`) whose keyset
  `AndroidKeysetManager` keeps in its own prefs file, wrapped by an Android
  Keystore master key; the ciphertext lives in its own DataStore file, never
  beside plain settings. `EncryptedSharedPreferences` is deprecated
  (security-crypto 1.1.0 deprecated every API); existing uses migrate by
  reading once and rewriting through the Tink path. The lifecycle is below.
- `BuildConfig.API_BASE_URL` comes from a Gradle property or the
  `API_BASE_URL` environment variable. No URL, key or flag is hard-coded.

## Sessions

What a strong generalist gets wrong here is the edges, not the happy path.

- Restore: read the stored session off the main thread (Keystore and file
  I/O are slow, sometimes hundreds of ms) and hold a neutral splash until
  it resolves (`installSplashScreen().setKeepOnScreenCondition`, or a
  loading state shown before the NavHost has a start destination); the
  sign-in screen is never drawn first. The start destination depends on
  having a stored session, not on the access token being unexpired: an
  expired access token with a live refresh token opens signed in. Never
  `runBlocking` in `onCreate` or a composable.
- Backup: rule 6. The ciphertext file and the keyset prefs file are
  excluded by exact path (`datastore/<name>.preferences_pb`,
  `sharedpref/<name>.xml`), matching the names the code uses.
- Key loss is normal, not exotic: restore to a new phone, a removed lock
  screen on some devices, an OS update. Any `GeneralSecurityException`,
  `KeyStoreException` or `ProviderException` while building the keyset or
  decrypting means signed out: delete the ciphertext AND the keyset (its
  prefs file and the Keystore alias), then rebuild a fresh keyset.
  Clearing only the ciphertext leaves a keyset that can never be
  unwrapped, so every later sign in fails too. Test that a sign in after
  key loss succeeds.
- Refresh: one OkHttp `Authenticator`; the refresh call goes through a
  client without it (or the Authenticator skips the auth paths), so a 401
  from refresh cannot recurse or deadlock. Single flight under one
  `Mutex`: inside it, if the stored access token differs from the one the
  failed request carried, retry with the stored one instead of refreshing.
  With rotating refresh tokens, sending an old one usually revokes the
  whole session, so persist the new pair before anything uses it. Give
  up after one retry (`response.priorResponse`). Refresh proactively
  when the stored expiry is past on start, with a small clock margin.
- Classify a failed refresh before acting on it. Only a verdict on the
  token (read the API contract: usually `400 invalid_grant`, sometimes a
  401 from the refresh endpoint) clears the session and routes to sign
  in. An `IOException`, a timeout, a 5xx or a 429 says nothing about the
  session: keep it, show cached data with an offline or retry state, and
  try again on the next request or start. Signing out on any refresh
  failure logs out everyone who opens the app without signal, the very
  complaint a "keep me signed in" change exists to fix.
- Sign out and refresh are serialized without making sign out wait on
  the network. One `Mutex` held across the refresh HTTP call and taken
  by sign out is correct but blocks sign out for up to the read timeout.
  Prefer a session generation: sign out bumps it and clears at once; a
  refresh, when its call returns, persists under a short lock only if
  the generation is unchanged. Either way a refresh in flight never
  writes the old session back after the clear (a restart would then
  show the user signed in again).
- Sign out: capture the tokens, clear local state, then revoke on the
  server best effort (application scope, short timeout, failures
  ignored) with the captured token. Local state means every per-user
  store: the session, Room tables (`clearAllTables()` or the user's
  tables), per-user DataStore, WorkManager jobs, notification and image
  caches. Settings meant to survive stay.
- Late writes: a fetch started under user A can land after the wipe and
  re-insert A's rows for user B. Cancel user-scoped work before wiping,
  and have the repository drop a result whose session (user id or
  generation) is no longer current, checked in the same transaction as
  the write.
- Tests: fakes for the cipher, the store and the API; cover restore,
  corrupt or undecryptable data, key loss then sign in, two concurrent
  401s sending one refresh, a refused refresh against an offline one,
  and sign out racing a refresh and an orders fetch.

## Security

- The launcher and link handlers (browsable VIEW filters, which must be
  exported) are the only exported components without a permission.
  Anything else exported carries a permission and a written reason in
  the manifest.
- Deep links and intent extras are validated before use: allow-list the
  host and path, parse ids (`toLongOrNull()` and a range check), reject the
  rest. A `getStringExtra` used directly in a query or URL is a finding.
  `Uri.lastPathSegment` and `getQueryParameter` return DECODED values, so
  `%2F` and `%3F` become `/` and `?`.
- Retrofit `@Path` rejects a value that forms a `.` or `..` segment
  (`IllegalArgumentException`), so `..` traversal is not the risk; with
  `encoded = true` a decoded `/`, `?` or `#` passes through and adds
  segments or a query to an authenticated request. Pass a parsed `Long`.
- An exported component receives explicit intents with no data at all;
  a custom scheme filter with no host matches every `scheme:` URI;
  `pathPrefix="/orders"` also matches `/ordersX` (use `pathPattern` or a
  `/orders/` prefix and validate in code). Links from email and the web
  need the activity exported; the fix is narrow filters plus validation.
- App Links (`autoVerify`) open the app only when
  `https://<host>/.well-known/assetlinks.json` lists the package and the
  release signing SHA-256 (the Play App Signing key, not the upload key);
  unverified links open the browser on Android 12+. A tapped URL that is
  a redirect (email click tracking, a URL shortener) carries the
  tracker's host, so a filter on your own host never sees it: turn
  tracking off for those links or verify the tracking domain too.
- A deep link can arrive on a cold start with no session in memory. It
  goes through the same restore and sign-in gate as the launcher, then
  returns to the target.
- `network_security_config.xml` forbids cleartext; debug builds that need a
  local API add a `debug-overrides` block under `src/debug/res/xml`.
- Release builds are minified and shrunk. kotlinx.serialization, Retrofit,
  OkHttp and Hilt bring their own keep rules, so `proguard-rules.pro` holds
  only rules for single classes those miss. A `ClassNotFoundException` in
  a release crash is a missing rule for that class, never a reason for a
  package-wide `-keep ... { *; }`.
- Signing configs come from CI variables. A keystore, `local.properties`
  or `google-services.json` in the repo fails the pre-commit hook.

## Testing

- Unit tests (`src/test`) run on the JVM with JUnit Jupiter (JUnit 6) through
  the `de.mannodermaus.android-junit` plugin. ViewModels are tested with a fake
  repository, `Dispatchers.setMain(StandardTestDispatcher())` and Turbine
  (`uiState.test { awaitItem() }`).
- Instrumented tests (`src/androidTest`) are JUnit 4: the AndroidX runner,
  `createComposeRule()` and Espresso are JUnit 4 rules and there is no
  supported Jupiter runner for them. Say so in the file header once.
- Compose tests drive the stateless `Screen` with a fixed state; only a
  flow test spins up Hilt (`HiltAndroidRule`, custom runner).
- No `Thread.sleep`, no `runBlocking` in a test, no real network. Fakes over
  mocks; a mock is acceptable for a third-party interface you do not own.
- Room tests run in `androidTest` against an in-memory database; every
  migration has one.

## Logging and observability

- One `Logger` interface injected; `Log.d` calls scattered in features are a
  finding. Debug builds print, release builds forward to the crash reporter.
- Never log a token, a password, PII or a full response body.
- Crash reporting and analytics are behind interfaces in `domain`, wired in
  `di`, so a test never hits a vendor SDK.

## Style

- ktlint (Android style, `.editorconfig` in the repo) and detekt decide
  style. Nothing is discussed in review that a tool decides.
- A public class or function gets a one-line KDoc saying what it is for.
- No `!!` outside tests. No `lateinit` for anything that can be a
  constructor parameter. No `object` singletons holding mutable state.
- Em dashes do not appear in comments, strings or docs.

## When the repository is Java

- Fields are `final`; classes are `final` unless designed for extension.
- Value types are `record`s (API 34+ or core library desugaring) or
  AutoValue. No hand-written `equals`/`hashCode`.
- `Optional` is a return type only, never a field or parameter. `@Nullable`
  and `@NonNull` (androidx.annotation) on every public signature.
- No raw types, no unchecked casts without a comment saying why.
- Threading through injected `Executor`s and `ListenableFuture` or RxJava
  as the repository already uses; `new Thread`, `AsyncTask` and
  `Handler(Looper.getMainLooper())` in feature code are findings.
- Errorprone or NullAway where the build already has them; do not add a
  second static analyser without a task.
- Mixed repositories: new files are Kotlin. A Java file is converted when a
  change touches more than half of it.
