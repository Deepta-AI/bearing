---
name: react
description: 'React house rules (React 19, TypeScript, Vite, TanStack Query, Zustand, Zod, shadcn/ui, Tailwind). Load before writing or changing React or TSX code. Use when asked for "a React component", "a query hook".'
allowed-tools: Read, Grep, Glob, Bash(pnpm install:*), Bash(pnpm run:*), Bash(pnpm exec:*), Bash(pnpm audit:*), Bash(make:*), Bash(npm run:*)
---

# react

The React stack on this standard: React 19, TypeScript strict, Vite, TanStack Query
for server state, TanStack Router for routing, Zustand for client state, Zod
at every boundary, shadcn/ui on Tailwind v4, vitest plus Testing Library for
units, Playwright for end-to-end, ESLint flat config, Prettier, pnpm, and an
nginx image for serving.

Router choice: TanStack Router over react-router. Links, params and search
params are typed, so a broken link is a type error; search params are
validated with Zod, which is the boundary rule applied to the URL; its
loaders call `queryClient.ensureQueryData`, so the cache stays the only copy
of server data. Code-based routes in `src/app/routes.tsx`, no file-routing
plugin and no generated route tree.

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.ts` or `.tsx` files: apply `references/guidelines.md`.
  Read it once per session, then work.
- Reviewing a diff with React files: apply `references/review-checklist.md`
  and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
  Open with the verdict (merge or not, and what blocks it). Take each
  line number from a numbered read of the file as it is on the reviewed
  branch, never from a diff hunk's offsets or from memory.
  A Low finding still names what goes wrong for a user or a maintainer;
  one that cannot is dropped, not padded.
- Scaffolding (`new-repo react-web <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them and appends the shared
  `.gitignore.append` to the skeleton's `.gitignore`. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

```
src/main.tsx                       mount only: StrictMode, root, App
src/app/                           App (providers), routes.tsx, layout, global stores
src/features/<feature>/api.ts      fetch functions, one per endpoint, Zod-validated
src/features/<feature>/schemas.ts  Zod schemas; types are z.infer, never a duplicate interface
src/features/<feature>/hooks.ts    query-key factory, queryOptions, useQuery/useMutation hooks
src/features/<feature>/components/ feature components; tests sit beside the code
src/components/ui/                 shadcn output: added with the CLI, never hand-edited
src/components/                    shared, feature-agnostic components
src/lib/                           api client, query client, env, utils (cn)
e2e/                               Playwright specs, one per user-facing flow
Makefile                           the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1, 2 (in whatever server-state library the
repository uses), 4 (validation at every boundary, Zod or the library
in place), 9, and no secret in a `VITE_` or other public variable.
Advisory: the directory layout, TanStack Router, Zustand, shadcn/ui,
Tailwind tokens (rule 8 applies only where Tailwind is configured) and
pnpm: use the router, state library, styling and package manager the
repository already has; propose a switch in an ADR, never inside a
feature change. Say which rule was relaxed and why.

## Rules that matter most

1. No `useEffect` to derive state. Compute during render; if it is expensive
   and measured, then `useMemo`. Effects are for synchronising with things
   outside React (subscriptions, focus, analytics).
2. The TanStack Query cache is the only copy of server data. Never mirror a
   query result into `useState` or a Zustand store; select with `select`,
   update with `setQueryData` or invalidate.
3. Zustand holds client-only state (UI toggles, drafts, selections). A store
   holding anything the server owns is a finding.
4. Zod schemas at every boundary (API responses, forms, URL search params,
   `import.meta.env`), and the type is `z.infer<typeof schema>`. A hand-written
   interface that shadows a schema is a finding.
5. Query keys come from a typed factory per feature (`invoiceKeys.detail(id)`)
   and are complete: every input that changes the result is in the key.
6. No prophylactic `useMemo`, `useCallback` or `React.memo`. Add them with a
   profiler screenshot or a measured re-render problem.
7. shadcn components are copied into `src/components/ui` with the CLI and used
   as-is. Do not wrap them in a `Button2`; extend with `className` and `cva`.
8. Tailwind uses the tokens in `src/index.css` (`bg-background`, `text-muted-foreground`,
   `p-4`). Arbitrary values (`w-[137px]`, `text-[#333]`) are a finding.
9. Accessibility: every interactive element is a `button`, `a` or form
   control, reachable by keyboard, with a visible label or `aria-label`;
   icons carry `aria-hidden`; async regions announce with `role="status"`.
10. `make check` = format-check, lint, typecheck, unit tests with coverage.
    CI runs the same target.

## Traps a strong generalist misses

Each of these has shipped past a competent author. Check them on every
change and every review they touch.

- **The URL is a public contract.** Search params outlive the code: they
  are pasted, bookmarked and generated by other tools. Before naming one,
  grep the repository and its docs for links already built to the route
  (emails, other internal tools, saved bookmarks in docs) and keep their names; prefer the
  API's own parameter name. Parse each param on its own
  (`schema.catch(undefined)` per field), so one bad value drops only
  itself. Trim free text before the length check and before it enters the
  URL or the request. Typing writes with `replace`, not one history entry
  per keystroke. A pasted `page` beyond the last page of the new result
  (the API returns empty items with a non-zero total) is clamped or
  offered a way back, never shown as "nothing matches".
- **Component state survives a route param change.** React Router and
  TanStack Router reuse the element when only `:id` changes, so a draft,
  an open form or a fetched result for record A is still there on
  record B. Per-entity local state needs `key={id}` on the component
  that owns it (or state keyed by id). Look for links from one entity's
  page to another's (related records, next and previous).
- **API text is untrusted, even from our own API.** Render it as text;
  keep line breaks with `whitespace-pre-line`, never by building HTML.
  `dangerouslySetInnerHTML` on anything a user or customer wrote is stored
  XSS in every viewer's session; when HTML is really required, sanitise
  with DOMPurify at render. An `href` from data needs an `http(s):` check.
- **Every request checks the status.** A raw `fetch` that ignores
  `res.ok` (typical on DELETE and other 204 calls) turns a 403 or a 500
  into success: the UI removes the item and it is still there. Route every
  call through the shared client, and give each mutation an error path the
  user can see.
- **Response enums drift.** Compare the feature's Zod enums with the API
  doc's changelog when touching it: one value the schema lacks fails the
  parse of the whole page. Tell the user when you add it.
- **Removing a leak does not undo it.** Dropping `persist` leaves the
  key already written on every machine that ran the build: ship a
  one-time `localStorage.removeItem(<key>)`. A secret that reached any
  built bundle (deployed, pilot, preview, shared) is rotated now; the fix
  alone does not recall it. Read the branch's commit messages and docs to
  learn whether it was ever deployed.
- **Checks not run are named.** Without `node_modules` or network, say
  which of lint, typecheck, tests and build were not run; never imply a
  pass.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (`pnpm exec <cmd>`, or the repository's `npm run`
scripts).

```
make setup      # pnpm install, Playwright chromium, git hooks
make dev        # vite dev server on :5173 with .env
make check      # prettier --check . ; eslint . ; tsc --noEmit ; vitest run --coverage
make fix        # prettier --write . ; eslint --fix .
make test-e2e   # playwright test (against a production build on :4173)
make test-e2e-matrix  # the same specs on chromium, firefox, webkit and two phones (CI after merge)
make test-visual      # e2e/visual/ against committed baselines, in the Playwright image
make test-visual-update  # rewrite baselines in the image; commit them on their own
make bundle-budget    # gzipped JavaScript under BUNDLE_BUDGET_KB (after make build)
make lighthouse       # Lighthouse CI: LCP, CLS, TBT and score from lighthouserc.json
pnpm dlx shadcn@4.21.0 add button   # add a shadcn component
```

## Gotchas

- `VITE_` variables are inlined into the bundle at build time and are
  public. A secret in one is shipped to every browser.
- Tailwind v4 has no `tailwind.config.ts`; theme tokens live in
  `src/index.css` under `@theme inline`. The Prettier plugin sorts classes.
- `pnpm-lock.yaml` is committed; CI installs with `--frozen-lockfile` and
  fails when the lock is stale.
- vitest runs with `retry: false` on the test QueryClient; a query test that
  hangs is usually a missing `retry: false`.
- Playwright mocks the API with `page.route`; a spec that reaches a real API
  is a flake waiting to happen.
- `src/components/ui/**` is excluded from ESLint and coverage like any
  generated code; typecheck still covers it.
