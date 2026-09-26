# Tracking plan

<!-- Template guidance: the rules every event follows: where events go, who
     a user is, what consent allows, what is stamped automatically and who
     owns change. The event sheet lists the events; this page is read before
     adding one. The defaults below are the standard; edit them to this
     product. Every comment says what goes there (What), what a strong entry
     has (Good) and an example (Example). Delete each comment when you fill
     its section. -->

The rules every event follows. The event sheet lists the events; this
page explains identity, consent, platforms and ownership.

## Destinations

<!-- What: each place events are sent, its purpose, its owner and the
     environment variable that holds its key.
     Good: the vendor is the one an accepted ADR chose, or the row says
     undecided and a console destination stands in; key names only, never
     values, since keys are configuration.
     Example: "PostHog EU cloud | funnels, retention | growth-team |
     `POSTHOG_API_KEY`" -->

| Destination | Purpose | Owner | Key location (name only) |
| --- | --- | --- | --- |
| product analytics (PostHog, Mixpanel, Amplitude) | funnels, retention | | `ANALYTICS_WRITE_KEY` |
| warehouse (ClickHouse, BigQuery) | reporting, joins with business data | | |

## Identity

<!-- What: the anonymous id, the user id and the tenant id, where each is
     stored, and when identify, alias and reset fire.
     Good: names the storage per platform this product ships on; the user
     id is never the email.
     Example: "- Anonymous id: generated on first launch, stored in MMKV
     (RN) under key anon_id." -->

- Anonymous id: generated on first launch, stored in local storage
  (web), MMKV or AsyncStorage (RN), DataStore (Android), UserDefaults
  (iOS). Never in a cookie readable by third parties.
- User id: the account id, never the email. `identify(user_id, traits)`
  fires on login and signup; `alias(anonymous_id, user_id)` once at signup;
  `reset()` on logout.
- Tenant id: standard property on every event for multi-tenant products.

## Consent

<!-- What: how consent gates every tracking call on each platform.
     Good: says where consent is required and that nothing is queued or sent
     before it there; names the module that checks it.
     Example: "- EU users: the banner in src/consent/Banner.tsx must return
     granted before analytics.init runs." -->

- No event leaves the device before consent where the law requires it.
- Consent state is a standard property; a change of consent is itself an
  event (`consent_updated`).

## Standard properties (stamped by the context layer, never by callers)

<!-- What: the properties the context provider adds to every event.
     Good: names the provider file; a caller that passes one of these by
     hand is a finding in the audit.
     Example: "Stamped in src/analytics/context.ts; tenant_id omitted,
     single-tenant product." -->

`app_version`, `build`, `platform` (web, ios, android, backend), `screen`,
`session_id`, `tenant_id`, `locale`, `experiment_variants`, `consent`.

## Naming

<!-- What: the naming and deprecation rule for events and properties.
     Good: a renamed event is a new event plus a dated deprecation of the
     old one, so dashboards do not break silently.
     Example: "`report_uploaded` deprecated 2026-10-01, replaced by
     `report_filed`." -->

Events `object_verb`, past tense, snake_case: `invoice_paid`,
`search_submitted`, `screen_viewed`. Properties snake_case. Enumerations
listed in the sheet. Never rename a shipped event; add a new one and
deprecate the old with a date.

## Ownership and change

<!-- What: who owns events and how a new or changed event gets in.
     Good: the sheet row lands in the same MR as the code and the owner
     reviews it; analytics-events audit is part of the definition of done.
     Example: "labs-team owns report_* events; audit runs in make check via
     the catalogue test." -->

Every event has an owner. A new or changed event is a row in the sheet in
the same MR as the code, reviewed by the owner. `analytics-events audit` runs in
the definition of done.
