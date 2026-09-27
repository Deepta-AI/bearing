# React Native review checklist

For each item, either find the concrete failure or write "none found".
Attribute a finding to the branch only when its line is in the diff from
the merge base; a defect on an untouched line is pre-existing.

## Rendering and lists
- `ScrollView` with `.map` over data that can exceed ten rows; a list
  without `keyExtractor`; index used as key; fixed-height rows without
  `getItemLayout` or `estimatedItemSize`.
- Row component not memoised while its parent re-renders on every
  keystroke; inline arrow or object literal passed to a row without a
  measured reason.
- An unbounded network image; an image without `width`/`height` or
  `contentFit`.
- Anonymous component defined inside another component's render.

## State
- `useEffect` that copies props or a query result into `useState`.
- Server data mirrored into Zustand, a ref or a module variable.
- Whole store subscribed (`useStore()` with no selector).
- Persisted state without `version` and `migrate`; rehydrated state not
  validated.
- Derived value stored instead of computed.

## Boundaries
- A `fetch` outside `src/lib/api.ts`; a response used without a schema;
  a type declared by hand that mirrors a schema.
- Route or deep-link params read without parsing; a deep link that grants
  access or navigates to a protected screen without the auth gate.
- `router.push` with a runtime-built string.
- A `z.enum` over a server-owned value that the changelog has already
  outgrown; a README or stale doc followed over the API reference or ADR.
- A post-sign-in `next` target used without checking it is an in-app path.
- Sign out that leaves the query cache for the next person on the phone.

## Storage and secrets
- A token, session or key in AsyncStorage, MMKV, Zustand `persist` or
  `app.json` `extra`.
- A secret in an `EXPO_PUBLIC_*` variable.
- SecureStore value that can exceed 2 KB.
- A storage key, signing secret or bucket URL in the app instead of a
  presigned URL from the API; a key the app made up (`Date.now()`) sent
  where the API expects its own upload id. A committed secret is rotated,
  not only deleted, and blocks the merge.

## Permissions and platform
- Permission requested on launch or before a rationale; `blocked` handled
  like `denied`; usage string or config plugin missing from `app.json`
  (iOS terminates the app on first camera or library access).
- A native module added while `version` stays the same under the
  `appVersion` runtime policy: an EAS Update reaches old binaries and
  crashes them.
- A photo uploaded at full quality with no resize or size check against
  the server's limit.
- Missing platform branch: `KeyboardAvoidingView` without a platform
  `behavior`, a shadow with no Android `elevation`, an iOS-only API called
  unguarded.
- Core `SafeAreaView` instead of `react-native-safe-area-context`; a
  custom header ignoring insets.
- A form without keyboard avoidance or `keyboardShouldPersistTaps`.

## Screens and errors
- A screen missing loading, error or empty; an error state without retry.
- A raw error message rendered in a `Text`.
- A floating promise in an event handler (`onPress={async () => ...}` with
  no `try/catch` and no mutation).
- No offline behaviour: a query that spins forever with no network, a
  mutation with no failure path.
- A submit button that stays enabled while the request runs; a create
  POST without an idempotency key, or with one made per request instead of
  once per user intent (a retry after a timeout creates a duplicate).
- A required choice silently defaulted (`reason ?? 'damaged'`); an action
  offered that the server will refuse (outside a window or status) with
  the 422 unmapped.
- An infinite list whose failed next page replaces the loaded rows with a
  full-screen error; `fetchNextPage` not guarded by `hasNextPage &&
  !isFetchingNextPage`; a single request where the API pages by cursor.

## Accessibility
- A pressable without `accessibilityRole`; an icon button without
  `accessibilityLabel`; a hit area under 44 pt with no `hitSlop`.
- Colour as the only signal for state.

## Bundle and dependencies
- A dependency added unasked; a version outside the SDK range (`npx expo
  doctor` fails); a native module without a note that Expo Go no longer
  works.
- A whole library imported for one function; `moment`, `lodash` root
  import, a large icon set imported wholesale.
- Fonts or images added without being registered in the root layout.

## Tests
- A bug fix without a reproducing test.
- New screens or hooks tested only through schemas or URL helpers.
- A test that hits the network, uses a real clock, or queries by test id
  where a role or text exists.
- A new user-facing flow without a Maestro flow.

## Hygiene
- `any`, `!`, `// eslint-disable` or `@ts-ignore` added; a rule disabled.
- Em dash in a comment, doc or user-facing string.
