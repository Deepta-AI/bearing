# React Native guidelines

## Project shape

- `app/` holds routes only. A route file wires hooks to components and owns
  nothing else; if it grows past a screen's worth of JSX, the pieces move to
  `src/features/<feature>/components`.
- `src/features/<feature>/` is split by domain, not by layer: `api.ts`,
  `schemas.ts`, `hooks.ts`, `components/`. A feature does not import another
  feature's internals; shared things move to `src/components` or `src/lib`.
- Names say what a thing is for: `useInvoices`, `InvoiceRow`,
  `invoiceSchema`. Never `utils`, `helpers`, `common`.
- One component per file, named export, file named after the component.
  Route files under `app/` are the exception: they are URLs, so kebab-case
  (`app/order-history.tsx`) as expo-router expects.
- `expo-env.d.ts` and `nativewind-env.d.ts` are committed; everything under
  `.expo/`, `ios/`, `android/` and `dist/` is generated and ignored.

## Server state: TanStack Query

- Every network read is a `useQuery`; every write is a `useMutation`. The
  query cache is the only copy of server data.
- Query keys are arrays built by a factory per feature:
  `invoiceKeys.list(filters)`, `invoiceKeys.detail(id)`. A string key is a
  finding.
- `staleTime` is set per query with a reason; the default 30 s in
  `src/lib/query-client.ts` is a starting point, not a decision.
- Mutations invalidate the narrowest key that covers the change. Optimistic
  updates roll back in `onError` and settle in `onSettled`.
- `onlineManager` follows NetInfo and `focusManager` follows `AppState`, so
  queries pause offline and refetch on foreground. Both are wired once in
  `src/lib/query-client.ts`.
- Never `useEffect` to copy a query result into state. Derive during render;
  use `select` to shape the data.

## Client state: Zustand

- One store per concern (`useSessionStore`, `useDraftStore`), small,
  selected with selectors: `useSessionStore((s) => s.userId)`, never the
  whole store in a component.
- `persist` with an MMKV or `expo-sqlite/localStorage` adapter (Expo
  deprecates AsyncStorage for new code), a `version` and a
  `migrate` function. Persisted state is validated with Zod on rehydrate;
  invalid state is discarded, not patched.
- Nothing secret is persisted through Zustand. Tokens live in
  `src/lib/secure-store.ts` and are read on demand.
- Actions live inside the store; components call actions, they do not `set`.

## Boundaries: Zod

- `src/lib/api.ts` takes a schema and returns the parsed type. A call site
  never sees `unknown` or `any`.
- Deep-link and route params are parsed with a schema in the screen; an
  invalid param renders the error state, it never navigates on.
- Push notification payloads, storage rehydration and `EXPO_PUBLIC_*`
  configuration are parsed once, where they enter.
- Types are `z.infer<typeof schema>`. A hand-written interface that mirrors
  a schema is a finding.

## Navigation: expo-router

- Routes are typed (`experiments.typedRoutes`). `router.push({ pathname:
  "/invoice/[id]", params: { id } })`, never a template string.
- Groups `(tabs)`, `(auth)` express layout, not ownership. Auth gating lives
  in one layout with `Redirect`, not in every screen.
- `Link` for anything the user taps to navigate; `router` only from event
  handlers and effects with a reason.
- Deep links: the scheme is declared once in `app.json`; universal and app
  links are verified (AASA, assetlinks) before release.

## Screens and components

- Every screen has three explicit branches: loading (skeleton or spinner
  with a label), error (message plus retry), empty (what to do next). The
  data branch comes last.
- `SafeAreaView` from `react-native-safe-area-context` (never the core one)
  at the screen root; `useSafeAreaInsets` for custom bars.
- Keyboard: `KeyboardAvoidingView` with `behavior` branched by platform
  around every form, and `keyboardShouldPersistTaps="handled"` on the
  scroll view that holds it.
- Lists: `FlashList` (with `estimatedItemSize`) or `FlatList` with
  `keyExtractor`; `getItemLayout` when rows are fixed height. Row
  components are `memo` with primitive props; handlers are `useCallback`
  when a profile shows re-renders, not by reflex. When an ADR turns on
  the React Compiler (`expo-upgrade` recommends it from the SDKs that
  support it), it memoises for you: stop adding `memo` and `useCallback`
  and remove them where the compiler reports it handles the component.
- Images through `expo-image` with explicit `width`/`height` or
  `contentFit`; never an unbounded network image.
- Platform branches through `Platform.select` or `.ios.tsx`/`.android.tsx`
  files; a `Platform.OS ===` chain longer than two is a component split.
- Accessibility: `accessibilityRole` on every pressable, `accessibilityLabel`
  when the visible text is not the label, `accessibilityState` for
  disabled and selected, minimum 44 pt hit area (use `hitSlop`).

## Styling: NativeWind

- Tokens (colours, spacing, radii, font sizes) live in `tailwind.config.js`;
  a hex literal in a component is a finding.
- Token names follow the web lanes' roles (`background`, `foreground`,
  `muted-foreground`, `primary`, `destructive`, `border`). The web side
  declares them as CSS variables because Tailwind v4 has no config file;
  NativeWind 4 needs Tailwind v3 and its JS config. Same names, two files:
  a rename on one side is made on the other in the same MR. When NativeWind
  5 is stable, the tokens move to `global.css` as `@theme` and the two
  sides can share one file.
- `className` for layout and tokens; `style` only for animated or measured
  values. Never both for the same property.
- Dark mode through the `dark:` variant with `userInterfaceStyle:
  "automatic"`; test both.
- Fonts are loaded in the root layout with `useFonts` and the splash screen
  is held until they resolve.

## Storage and secrets

- `expo-secure-store` for tokens, refresh tokens, device keys. Values are
  under 2 KB; anything bigger is encrypted to the file system with a key in
  secure store.
- `expo-sqlite/localStorage`, MMKV and any existing AsyncStorage hold
  caches and preferences only. Assume all are readable on a rooted device.
- `EXPO_PUBLIC_*` variables ship inside the bundle. API URLs and feature
  toggles belong there; keys do not. Secrets that the app truly needs at
  runtime are fetched after login, never embedded.
- `app.json` `extra` is public. Nothing in it that would matter in a
  decompiled APK.

## Permissions

- Ask when the feature is used, after a rationale screen or sheet that
  says why and has a decline path. Never on launch, never in a loop.
- Handle `denied` and `blocked` separately: blocked opens settings with
  `Linking.openSettings()`, denied shows the feature's fallback.
- Declare every usage string in `app.json` (`infoPlist` and `permissions`);
  an undeclared permission crashes on iOS and is stripped on Android.

## Networking and errors

- `src/lib/api.ts` is the only `fetch`. It sets the base URL, JSON headers,
  the bearer token from secure store, a timeout, and throws `ApiError`
  with status and parsed body.
- 401 triggers one refresh, then logout; both live in the client, not in
  screens.
- Event handlers `await` inside `try/catch` or hand off to a mutation. A
  floating promise in a handler is a finding.
- Errors shown to users are mapped once from `ApiError` to copy; the raw
  message never reaches a `Text`.
- Certificate pinning on money and auth paths through `expo-build-properties`
  or a pinned client; documented in `SECURITY.md`.

## Testing

- `jest-expo` preset, Testing Library queries by role and text, never by
  test id unless the element has no accessible name.
- One test file next to the component: `HealthCard.test.tsx`. Hooks are
  tested through a component or `renderHook` with a fresh `QueryClient`
  (`retry: false`) per test.
- Network is mocked at the `api.ts` boundary or with MSW; a test that hits
  the network is a failure.
- Fake timers for anything time-based; no `setTimeout` waits, no real
  clock.
- Maestro: one YAML flow per user-facing journey in `.maestro/`, run
  against a preview build on a simulator or device. `assertVisible` on
  text the user sees; `id` only for elements with no text.

## Delivery

- `eas.json` profiles: `development` (dev client, internal),
  `preview` (internal, APK plus simulator build), `production` (store).
- EAS Update ships JavaScript and assets only. A change that adds a native
  module or bumps a native dependency needs a new build, and the runtime
  version policy (`appVersion`) makes updates refuse to apply to an old
  binary.
- Version in `app.json`; build numbers are managed remotely by EAS
  (`autoIncrement`).
- `npx expo doctor` passes before every MR; a dependency outside the SDK's
  expected range is fixed with `npx expo install --fix`, not pinned by hand.

## Style

- Prettier and ESLint decide style. Nothing is discussed in review that a
  tool decides.
- Doc comment on every exported function and component, one line, what it
  is for.
- Function components only; props typed inline or as `Props`, never
  `React.FC`.
- No `any`; `unknown` plus a schema. No `!` non-null assertions outside
  tests; narrow instead.
