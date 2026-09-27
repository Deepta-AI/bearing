---
paths: ["app/**/*.tsx", "src/**/*.ts", "src/**/*.tsx"]
---

# React Native rules (loaded when an app/ or src/ file is touched)

- Server state only in TanStack Query; never copied into Zustand, state or
  a ref. Query keys from a per-feature factory. No `useEffect` deriving
  state.
- Zustand for client state, read through selectors; `persist` only for
  data safe to read off a rooted phone, with `version` and `migrate`.
- Tokens and secrets in `expo-secure-store`; never AsyncStorage, localStorage, MMKV,
  `app.json` `extra` or an `EXPO_PUBLIC_*` variable.
- Zod at every boundary: API responses through `src/lib/api.ts`, route and
  deep-link params, rehydrated state. Types are `z.infer`, never mirrored.
- Lists: `FlashList` or `FlatList` with `keyExtractor` (and `getItemLayout`
  for fixed rows); no `ScrollView` with `.map`; no inline row props without
  a measured reason.
- Navigation through typed routes; `router.push` never takes a built
  string. Deep links are parsed and never bypass the auth gate.
- Permissions at the moment of use after a rationale; `blocked` opens
  settings.
- Cursor APIs use `useInfiniteQuery`; a failed next page keeps the loaded
  rows. Create POSTs carry an idempotency key made once per user intent;
  the submit is disabled while pending. Sign out clears the query cache.
- Every screen: loading, error with retry, empty. Errors mapped to copy
  once; no raw message in a `Text`; no floating promise in a handler.
- `accessibilityRole` on every pressable, `accessibilityLabel` when the
  text is not the label, 44 pt hit area.
- Safe areas from `react-native-safe-area-context`; platform-branched keyboard avoidance around every form.
- No `any`, no `!`, no `eslint-disable` or `@ts-ignore` without a task id
  and reason on the same line.
