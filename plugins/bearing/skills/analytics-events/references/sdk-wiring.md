# SDK wiring per platform

Every codebase gets one `analytics` module. Components, screens and
handlers call it; nothing else calls a vendor SDK.

## Shape of the module

```
track(event: EventName, props: EventProps[EventName]): void
identify(userId: string, traits: Traits): void
alias(anonymousId: string, userId: string): void
screen(name: string, props?: object): void
reset(): void
setContext(partial: Context): void        // app_version, tenant_id, consent ...
```

The `EventName` and `EventProps` types are generated from the event sheet
(`make analytics-catalogue`, a small script per stack that reads
`docs/analytics/EVENT_SHEET.md` and writes the catalogue file). A call
with an unknown event or a wrong property does not compile.

## Web (React)

- `src/analytics/index.ts` exposes the module; `src/analytics/events.ts`
  is generated. Vendor client created once in `src/analytics/client.ts`
  from `VITE_ANALYTICS_WRITE_KEY` (public by design; the key is a write
  key, not a secret).
- `screen` is called from the router's navigation subscription, never
  from components.
- Debug mode (`VITE_ANALYTICS_DEBUG=true`) logs each call to the console
  and sends nothing.
- Consent gate: the module buffers nothing before consent; calls are
  dropped and counted.

## React Native (Expo)

- `src/analytics/` with the same shape; vendor client from
  `EXPO_PUBLIC_ANALYTICS_WRITE_KEY`.
- `screen` from the expo-router navigation listener.
- Offline queue with a bounded size (500 events) persisted in MMKV,
  appended under one lock (no concurrent read-modify-write); a flush
  sends batches no larger than the collector accepts and removes only
  the events it sent, only on a 2xx (`fetch` does not throw on 4xx or
  5xx). Flushed on foreground, cleared on `reset()`.
- The consent answer is persisted and restored at start-up before the
  first `track`, or every later session sends nothing.
- App lifecycle events from `AppState`.

## Android (Kotlin)

- `analytics/Analytics.kt` interface with a Hilt binding to the vendor
  implementation; `analytics/Events.kt` generated sealed class per event
  with typed properties.
- `screen` from a `NavController.OnDestinationChangedListener`.
- Lifecycle events from `ProcessLifecycleOwner`.
- Debug build flavour logs to Timber and sends nothing.

## iOS (Swift)

- `Analytics/Analytics.swift` protocol with a concrete vendor client
  injected through the app container; `Analytics/Events.swift` generated
  enum with associated values.
- `screen` from a view modifier applied at the navigation root.
- Lifecycle events from `ScenePhase`.
- Debug configuration logs with `os.Logger` and sends nothing.

## Backend (Go, Python)

- `internal/analytics` or `app/analytics` with an `Emitter` interface, a
  vendor implementation, and a fake for tests.
- Server-side outcomes only (payments, signups, subscription changes).
- Events carry the request id for joining with logs.
- Emission is asynchronous with a bounded queue; a full queue drops and
  increments a metric, never blocks the request.

## Warehouse destination

Events land in ClickHouse (or BigQuery) in one wide table: `event_name`,
`event_time` (DateTime64 UTC), `user_id`, `anonymous_id`, `tenant_id`,
`platform`, `properties` (JSON string), plus the standard properties as
columns. `ORDER BY (tenant_id, event_name, event_time)` for the queries
analysts run.
