# flutter: layout

Read when scaffolding or placing a new file: the directory layout and what each file owns.

```
lib/main.dart                     boot only: config check, logging, ProviderScope, runApp
lib/app.dart                      MaterialApp.router: theme, l10n delegates, router
lib/router.dart                   GoRouter: routes, error page; names, never string paths
lib/core/config.dart              AppConfig from dart-define; validated at boot
lib/core/http.dart                dio factory plus request-id, logging, retry interceptors
lib/core/logging.dart             package:logging routed to dart:developer; no print
lib/features/<f>/<f>.dart         freezed model with fromJson
lib/features/<f>/<f>_repository.dart   the only place IO happens; typed results, typed errors
lib/features/<f>/<f>_provider.dart     Riverpod providers: repository, async state
lib/features/<f>/<f>_page.dart         ConsumerWidget: layout only; loading, error, data
lib/l10n/app_en.arb               strings; generated code lands in lib/l10n/generated
config/{dev,staging,prod}.json    flavour values for --dart-define-from-file; no secrets
test/, integration_test/          mirrors lib/; one smoke flow in integration_test
android/fastlane, ios/fastlane    store lanes; run by a person, printed by the agent
Makefile                          the only entry point: help setup dev check fix test doctor
```
