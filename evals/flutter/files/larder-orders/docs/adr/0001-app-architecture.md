# 1. App architecture

Status: Accepted (2025-11-04)

## Context

Larder's first version mixed network calls into widgets and was hard to
test.

## Decision

- State lives in Riverpod providers. Widgets lay out and read providers;
  they make no network or storage calls.
- A repository per feature is the only code that touches `Dio`. It
  returns typed models and throws the typed exceptions in
  `lib/core/errors.dart`; no `Response` or JSON map leaves it.
- Models are freezed classes with `json_serializable`; the generated
  files are built by `make gen` and never committed.
- Routes are declared by name in `lib/router.dart` and navigated with
  `goNamed` or `pushNamed`. Route and deep-link parameters are validated
  before use.
- Every user-facing string is in `lib/l10n/app_en.arb`.
- Every screen shows loading, an error with a retry, and data.
- A new package needs a short ADR first.

## Consequences

Tests fake the HTTP adapter or override providers; no test touches the
network.
