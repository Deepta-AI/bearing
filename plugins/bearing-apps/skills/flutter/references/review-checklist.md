# Flutter review checklist

For each item, either find the concrete failure or write "none found".

## Widgets
- Logic in `build`: JSON parsing, arithmetic on domain values, a network
  or storage call, a `Future` started without a provider.
- A widget over 200 lines or with more than one public class; a `build`
  that returns a deeply nested tree instead of extracting widgets.
- A missing `const` where the analyser allows one; a `ListView` built
  with `children` over a long list instead of `ListView.builder`.
- A list item without a stable `Key`; a `GlobalKey` created in `build`.
- `MediaQuery.of(context)` or `Theme.of(context)` read repeatedly in a
  loop; a hard-coded colour or text style outside the theme.
- `initState` doing work that belongs in a provider; a controller or
  subscription without `dispose`.

## State and providers
- `setState` holding server data; a query result copied into a widget
  field; a global mutable variable or singleton.
- A provider that never disposes (`keepAlive` without a reason) or one
  disposed while a screen still needs it.
- `ref.read` in `build` where `ref.watch` is meant; `ref.watch` inside a
  callback.
- A `FutureProvider` re-created on every rebuild because its family
  argument is a new object each time.
- Retry that does not `ref.invalidate` the provider, so the error stays.

## Repositories and network
- A `Response`, `Map<String, dynamic>` or `dynamic` returned past the
  repository; a model without `fromJson` through `json_serializable`.
- A `DioException` escaping the repository unmapped; a catch that
  swallows and returns null.
- A request without a timeout; a retry on a non-idempotent call (POST);
  a request id missing because the interceptor was bypassed.
- A token, body or personal value in a log line or an error message.

## Navigation and configuration
- A string path pushed instead of a named route; a route parameter used
  without validation; a deep link that grants access.
- A secret in `config/*.json`, a `--dart-define`, an asset or the
  pubspec; a hard-coded API URL.
- A flavour check by string comparison scattered through the code instead
  of `AppConfig`.

## Accessibility and l10n
- An icon button without a `Tooltip` or `Semantics` label; a touch
  target under 48 dp; text with `textScaler` overridden to 1.
- A user-facing literal string not in the ARB file; a plural or a date
  formatted by hand.
- A colour pair that fails contrast; state conveyed by colour alone.

## Platform and release
- A permission requested at launch instead of at the moment of use, or
  without a rationale.
- A dependency added unasked; a plugin without a matching platform
  setup on both stores.
- A change under `android/` or `ios/` that a `flutter create` regenerates
  (the change belongs in the template or the pubspec).
- A fastlane lane that ships without a person: no manual trigger, no
  environment protection.

## Tests
- A bug fix without a reproducing test.
- A widget test without the localisation delegates (`AppLocalizations`
  throws); a test that waits with `Future.delayed` instead of `pump`.
- A test that hits the real network; a repository test without a fake
  adapter; a screen without a test for its error branch.
- An integration test that depends on the API being up.

## Hygiene
- `// ignore:` or `// ignore_for_file:` added without a task id; a lint
  rule disabled in `analysis_options.yaml`; generated files edited by
  hand or committed.
- Em dash in a comment or doc.
