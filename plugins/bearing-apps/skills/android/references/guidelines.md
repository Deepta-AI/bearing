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
  `AndroidKeysetManager` keeps in the `tink_keyset` prefs file, wrapped by an
  Android Keystore master key; the ciphertext lives in DataStore. The keyset
  file and the DataStore directory are excluded from backup in both
  `backup_rules.xml` and `data_extraction_rules.xml`, since the Keystore key
  never leaves the device. `EncryptedSharedPreferences` is deprecated
  (security-crypto 1.1.0 deprecated every API); existing uses migrate by
  reading once and rewriting through the Tink path. Refresh through one
  `Authenticator`, never by hand in a repository.
- `BuildConfig.API_BASE_URL` comes from a Gradle property or the
  `API_BASE_URL` environment variable. No URL, key or flag is hard-coded.

## Security

- The launcher activity is the only exported component. Anything else
  exported carries a permission and a written reason in the manifest.
- Deep links and intent extras are validated before use: allow-list the
  host and path, parse ids, reject the rest. A `getStringExtra` used
  directly in a query or URL is a finding.
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
