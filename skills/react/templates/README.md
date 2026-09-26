# __REPO_NAME__

React web app. `make help` lists every command; `make check` is the gate.

## Run

```
cp .env.example .env
make setup          # pnpm install (writes pnpm-lock.yaml; commit it), Playwright chromium, git hooks
make dev            # http://localhost:5173
```

`make check` prints one `<gate>: N ... checked` line per gate (format,
lint, typecheck, unit tests with MSW, dependency audit) and a final tally. A
gate whose tool is missing prints `SKIPPED` and the tally fails;
`BEARING_ALLOW_SKIP=1 make check` lets a laptop through and is never set in CI.
`make test-e2e` (Playwright) needs a browser and is a CI job, not part of
`check`.

## Layout

See `AGENTS.md` and the `react` skill for the conventions. `src/app`
wires (providers, routes, `RootLayout` with its Suspense boundary,
`RouteError` for route failures, `NotFound`), `src/components/ErrorBoundary`
is the last line above the providers, `src/features/<feature>` owns a domain
(`api`, `schemas`, `hooks`, `components`), `src/components/ui` is shadcn
output, `src/lib` holds the api client, query client and env parsing,
`src/test` holds the render helpers and the MSW server, `e2e/` holds
Playwright specs.

## Tests and MSW

`src/test/msw.ts` starts a Mock Service Worker for every unit test with one
handler per API route the app calls; an unhandled request fails the test. A
test that needs another answer calls `server.use(...)` for its own scope.
`vitest.config.ts` sets `VITE_API_URL` to an absolute origin so the URLs
match in node.

## Add a shadcn component

```
pnpm dlx shadcn@latest add dialog
```

`src/components/ui/button.tsx` is the example the generator produced; files
in that folder are not linted and are regenerated, not hand-edited.

## Image

```
docker build --build-arg VITE_API_URL=/api -t __REPO_SLUG__ .
docker run --rm -p 8080:8080 __REPO_SLUG__
```
