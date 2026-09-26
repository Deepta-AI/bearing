# HTTP logging interceptor: React Native (Expo)

File: `src/lib/api.ts` is the only `fetch`; the interceptor wraps it.
Logging goes through `src/lib/log.ts`. Toggles are a small store so the
debug menu can flip them without a rebuild.

## Configuration

```ts
// src/lib/http-log.ts
import AsyncStorage from "@react-native-async-storage/async-storage";

type HttpLogConfig = { enabled: boolean; bodies: boolean; maxBytes: number; sample: number };
const defaults: HttpLogConfig = {
  enabled: process.env.EXPO_PUBLIC_LOG_HTTP === "true" || __DEV__,
  bodies: process.env.EXPO_PUBLIC_LOG_HTTP_BODIES === "true",
  maxBytes: Number(process.env.EXPO_PUBLIC_LOG_HTTP_MAX_BYTES ?? 2048),
  sample: Number(process.env.EXPO_PUBLIC_LOG_HTTP_SAMPLE ?? 1),
};
export let httpLog: HttpLogConfig = { ...defaults };

export async function loadHttpLogConfig(): Promise<void> {
  const raw = await AsyncStorage.getItem("http-log");
  if (raw) httpLog = { ...defaults, ...JSON.parse(raw) };
}
export async function setHttpLogConfig(patch: Partial<HttpLogConfig>): Promise<void> {
  httpLog = { ...httpLog, ...patch };
  await AsyncStorage.setItem("http-log", JSON.stringify(httpLog));
}
```

`loadHttpLogConfig()` runs in the root layout before the first query.

## Interceptor

Same body as the web `loggedFetch` (see `react.md`), reading `httpLog`
from this module. Two differences: the response body is read with
`res.clone().text()` only when `bodies` is on, because cloning large
downloads on a phone is expensive; and `request_id` is also attached as
a breadcrumb to the crash reporter so a crash report links to the last
requests.

## Flipping it at runtime

- Debug menu (shake, or the dev client menu): a "HTTP logging" screen
  under `app/(debug)/` with three switches bound to
  `setHttpLogConfig`. The screen is compiled only when
  `EXPO_PUBLIC_DEBUG_MENU=true`; release builds do not include it.
- Remote config, when the app has it: a boolean `log_http` applied
  through `setHttpLogConfig` on fetch, so support can enable it for one
  user's session without a build.
- Build default: `EXPO_PUBLIC_LOG_HTTP*` in `.env.example`; preview
  builds may set `true`, production sets none.

## Test

Jest with `global.fetch = jest.fn()` and a spy on the log module: off
logs nothing, on logs two lines, `setHttpLogConfig({ bodies: true })`
redacts `password` and truncates at `maxBytes`.
