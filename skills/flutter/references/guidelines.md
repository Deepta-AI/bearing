# Flutter guidelines

## Project shape

- `lib/main.dart` boots: validates `AppConfig`, configures logging, runs
  the app inside a `ProviderScope`. Nothing else lives there.
- `lib/app.dart` is the `MaterialApp.router` with theme, localisation
  delegates and the router. `lib/router.dart` declares every route by
  name.
- `lib/core/` holds cross-cutting code: config, http, logging, theme.
- `lib/features/<feature>/` owns one domain: the freezed model, the
  repository (IO), the providers (state), the page and its widgets.
  Nothing outside the feature imports its internals except through the
  providers and the page.
- The package is named `app`, fixed, because a Dart package name must be
  an identifier; the product name lives in the ARB file and the stores.
- A file under 200 lines with one public class. Extract widgets into
  files, not into private `_build` methods.

## State with Riverpod

- Riverpod over Bloc because the same code declares a dependency, a
  cached value and an async state, and the widget tree stays flat. Bloc
  is the `tech-decision` alternative for a team that already thinks in
  events and states; a repository with a Bloc app keeps Bloc.
- `Provider` for services (repository, dio), `FutureProvider` for a read
  the screen awaits, `Notifier` for state the user changes,
  `AsyncNotifier` for state that loads then changes. `StateProvider` and
  `StateNotifier` are legacy; do not add them.
- `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for side
  effects (a snackbar on error). Never `ref.watch` inside a callback.
- Retry is `ref.invalidate(provider)`; the screen rebuilds through the
  loading branch. Riverpod 3 also retries a failing provider by itself
  with backoff; pass `retry: (count, error) => null` where a button owns
  the retry, and set a bound where the default is kept.
- Auto-dispose by default; `keepAlive` only with a comment saying why the
  value must outlive the screen.
- Ephemeral widget state (a text field, an expanded flag) is `setState`
  or a hook, not a provider.

## Repositories and network

- `dio` created once in `core/http.dart` with `BaseOptions` (base URL from
  `AppConfig`, connect and receive timeouts, JSON accept header) and three
  interceptors: request id (`x-request-id`), logging (method, path,
  status, duration; never headers or bodies), retry (idempotent methods
  only, bounded attempts, backoff).
- A repository takes the `Dio` through its constructor, calls one
  endpoint per method, parses with the model's `fromJson`, and maps
  `DioException` to a typed exception (`NetworkException`,
  `ApiException(status)`). Nothing above the repository sees dio.
- Models are `freezed` classes with `fromJson` through
  `json_serializable`; fields are typed, nullable only when the API can
  omit them. Generated files are not committed; `make gen` writes them.
- Every call has a timeout. A background sync has an owner that cancels
  it on sign-out.

## Navigation

- `go_router` with named routes; navigate with `context.goNamed` and
  typed parameters, never a string path built at runtime.
- Deep links and query parameters are validated (parsed, range-checked)
  before use and never used for authorisation; the server decides.
- Redirects for auth in the router's `redirect`, reading a provider, not
  scattered `if` checks in pages.
- An `errorBuilder` page for unknown routes.

## Configuration and flavours

- `--dart-define-from-file=config/<flavour>.json` for dev, staging and
  prod. `AppConfig` reads each value with `String.fromEnvironment` and
  validates at boot; a bad value stops the app with a clear message.
- Why dart-define over `flutter_dotenv`: values are compile-time
  constants (tree-shaken, no asset to leak, no runtime file read) and the
  same JSON drives `flutter run`, `flutter build` and CI.
- Defines are readable from the binary: configuration only. Secrets come
  from the API after sign-in and live in `flutter_secure_storage`.
- Gradle product flavours or Xcode schemes are added only when the stores
  need distinct bundle ids; the JSON flavour is enough for URLs and flags.

## Localisation

- `flutter_localizations` with `l10n.yaml`; strings in `lib/l10n/app_en.arb`
  with descriptions and placeholders; `AppLocalizations.of(context)` in
  widgets. A user-facing literal in a widget is a finding.
- Plurals and dates through ICU messages and `intl`, never by hand.
- Generated code lands in `lib/l10n/generated` and is git-ignored.

## Widgets and accessibility

- `const` constructors everywhere the tree allows; `flutter analyze
  --fatal-infos` with `prefer_const_constructors` enforces it.
- Lists through `ListView.builder` with stable keys; images with a size
  and a placeholder; long text respects the system text scale.
- Every interactive element: a visible label or a `Tooltip` or
  `Semantics(label:)`, a 48 dp touch target, a visible focus. Loading
  and result regions use `Semantics(liveRegion: true)` so screen readers
  announce them.
- Theme tokens from `ThemeData` (`colorScheme`, `textTheme`); no raw
  colours or sizes in widgets.
- Golden tests are optional; add them for design-system widgets, not for
  screens that change weekly.

## Logging

- `package:logging`, configured once in `core/logging.dart` and routed to
  `dart:developer` `log` (visible in DevTools, stripped of nothing in
  release, so nothing sensitive is ever logged). Level from the flavour.
- Never `print`. Never a token, a body or a personal value.

## Testing

- `flutter_test` units for config, interceptors, repositories (a fake
  `HttpClientAdapter` answers dio) and providers (`ProviderContainer`
  with overrides).
- A widget test per screen: pumped inside `ProviderScope` with overrides
  and inside `MaterialApp` with the localisation delegates; asserts the
  loading, error-with-retry and data branches by finder.
- `integration_test/app_test.dart` boots the real app with the repository
  overridden and walks one flow. It runs on a device, an emulator or a
  desktop target through `make test-integration`, never in `check`.
- Deterministic: no `Future.delayed` in tests; `pump` and `pumpAndSettle`
  drive time. No real network.
- `flutter test --coverage` writes `coverage/lcov.info`; a bug fix ships
  with its test.

## Release

- `make build-android` and `make build-ios` produce the artefacts from
  `config/prod.json`. `flutter build ipa` needs macOS and Xcode; Linux CI
  builds the APK only and says so.
- fastlane lanes in `android/fastlane` and `ios/fastlane` upload to the
  internal track and TestFlight; a person runs them (`make
  release-android` prints the command). Signing keys and service-account
  JSON never enter the repository.
- Version and build number come from the pubspec `version: x.y.z+n`; CI
  overrides `+n` with the pipeline id.

## Style

- `dart format` and `flutter analyze` decide style. Nothing is discussed
  in review that a tool decides. `very_good_analysis` is the stricter
  optional set; enable it in `analysis_options.yaml` for a new app.
- Doc comments on every public class and function, one line, saying what
  it is for. Comments explain why.
- `// ignore:` only with a task id and a reason on the same line.
