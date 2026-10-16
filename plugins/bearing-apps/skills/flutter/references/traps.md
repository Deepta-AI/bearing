# flutter: traps a strong generalist still ships

Read before finishing a change that touches writes, lists, values, side effects, push notifications or tests.

Each of these passes a read-through and fails on a phone. Check every one
that the change touches, in new code and in the code it relies on.

Writes the user triggers (add, reorder, pay, toggle):

- Read the retry interceptor before adding a write. One that retries
  every method on a timeout or 5xx repeats a POST the server already
  committed: the items go in twice. Limit automatic retry to idempotent
  methods (the skeleton retries GET, HEAD and OPTIONS) or to requests
  carrying an idempotency key,
  and name the existing calls that were exposed (fix them or say so).
- An idempotency key belongs to one user intent, not one request. Make
  it when the user starts the action; reuse it for every automatic retry
  and for the user's own retry after an unknown outcome (timeout,
  connection error, 5xx); drop it only on a definite answer (2xx or 4xx).
  Keep it in state that outlives the row: an `autoDispose` family
  provider disposed when the row scrolls away loses it.
- Double taps: the control is disabled while its request is in flight,
  keyed by the item, and a second tap is ignored, not queued.
- After every `await` the widget may be gone: `if (!context.mounted)
  return;` before using `context`, `if (!mounted) return;` before
  `setState`, and `ref.mounted` in a Riverpod 3 notifier before setting
  `state`.
- Optimistic UI (a switch flipped before its PUT) rolls back and tells
  the user when the write fails; otherwise the screen shows a setting the
  server does not hold.
- Show what the server actually did: a partial success (some items
  unavailable) names what was left out, and so does a total miss (nothing
  added still lists the items by name); a plain "done" on every 200
  hides it.

Lists and values:

- Paginated endpoints: follow the cursor until it is null; raising
  `limit` past the documented cap is not paging. One page request in
  flight at a time (scroll fires many events), pages appended once, an
  error on page n keeps the loaded pages and offers a retry at the end,
  refresh resets the cursor and replaces the list. Test page two and the
  end.
- A timestamp ending in `Z` parses to a UTC `DateTime`, and `DateFormat`
  prints it in UTC: call `.toLocal()` first, or an order placed at 18:42Z
  shows the previous day in India.
- Money is integer minor units plus a currency code, formatted by the
  repository's helper or `NumberFormat.simpleCurrency`; never a `double`
  and never `toStringAsFixed`.
- Enum-like server values (`out_for_delivery`) map to translated labels
  with a fallback for an unknown value; never a raw value on screen.
- The other way, a Dart enum's `.name` is not a wire value:
  `TargetPlatform.iOS.name` is `iOS` where an API may want `ios`. Map to
  the documented strings explicitly and check each one against the API
  document.

Side effects and lifecycle:

- `build` runs on every rebuild. Registering, subscribing, posting,
  navigating or starting a `Future` there (including
  `ref.read(x).start()`) repeats it and stacks listeners. Start once: in
  `main`, in a provider body with `ref.onDispose` cancelling the
  subscription, or in `initState` with `dispose`. An unawaited `Future`
  sends its error nowhere.
- `catchError((_) {})` or an empty `catch` turns every failure into an
  endless spinner; an error needs a state and a retry.

Push notifications (`firebase_messaging`):

- Three tap paths: `getInitialMessage` (cold start from terminated),
  `onMessageOpenedApp` (background), `onMessage` (foreground, where the
  system shows no banner by itself). Handling one loses the others.
- `getToken` can return null or throw (iOS before the APNs token exists,
  no Play services, offline): guard it, keep it inside the error
  handling, and never post a null token. Listen to `onTokenRefresh` and
  register again; unregister on sign-out so the next account on the
  device does not get this user's updates. The token addresses pushes to
  the device: never log it.
- The background handler is a top-level or static function annotated
  `@pragma('vm:entry-point')`. Without the annotation it works in debug
  and can be stripped from release builds; an anonymous closure throws.
- It runs in its own isolate: no `ProviderScope`, no logging that `main`
  configured, no memory shared with the app. It re-initialises what it
  uses and writes anything it must record to storage or the server; a
  handler that only logs does nothing, whatever its comment says.
- `Firebase.initializeApp()` needs `options:` (`firebase_options.dart`)
  or the platform files (`google-services.json`,
  `GoogleService-Info.plist`). With neither in the repository it throws
  before `runApp`, so the app never draws a frame.
- The payload is untrusted input: read the documented keys, validate the
  id, navigate by route name. `router.go(payload['link'])` both misses
  the real key and lets a payload open any path.
- The permission prompt comes when the user sees its value (and as the
  project's decision records say); Android 13 and later also need
  `POST_NOTIFICATIONS` in the manifest.
- A shared secret in a define, an asset, `.env` or secure storage ships
  in the binary and is extractable; once committed it is leaked: rotate
  it and authenticate with the user's session instead. Obfuscation and
  moving it are not fixes.

Tests:

- `testWidgets` runs on a fake clock: `await Future.delayed(...)` in the
  body never completes and hangs the whole suite (so `make check` never
  finishes). Use `pump`, `pumpAndSettle`, or `tester.runAsync` for real
  IO. `pumpAndSettle` never settles while a `CircularProgressIndicator`
  spins; assert the loading branch after a single `pump`.
- Plugins have no platform side under `flutter test`:
  `FirebaseMessaging.instance` in a widget test throws. Put the plugin
  behind a provider and override it.
- Cover the branches that fail in production: error with retry, empty,
  the failed write, page two, the double tap.
