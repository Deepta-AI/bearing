# Larder

The Larder grocery app for Android and iOS: browse, fill a cart, order.
Flutter 3.35 on Dart 3, Riverpod for state, go_router, dio.

## Getting started

```
make setup   # packages, then freezed, json and l10n code (generated files are not committed)
make dev     # runs against the dev API with config/dev.json
make check   # format check, flutter analyze --fatal-infos, flutter test
```

`android/` and `ios/` are created by `flutter create .` on each machine and
are not committed yet.

## Layout

- `lib/core/`: config, http client, logging, money formatting, errors.
- `lib/features/<feature>/`: model, repository, providers, page.
- `lib/l10n/app_en.arb`: every user-facing string.

## Prices

The API returns rupee amounts as decimals (`price`, `total`). Show them
with `toStringAsFixed(2)` and a rupee sign.

## Flavours

`config/dev.json`, `config/staging.json` and `config/prod.json` are passed
with `--dart-define-from-file`. They hold configuration only.
