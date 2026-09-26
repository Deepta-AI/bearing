# __REPO_NAME__

React Native app on Expo SDK 57. `make help` lists every command; `make check`
is the gate.

## Run

```
cp .env.example .env
make setup        # pnpm install (writes pnpm-lock.yaml; commit it), git hooks
make dev          # scan the QR code with Expo Go, or press i / a for a simulator
```

A native module outside Expo Go needs a dev client once: `make ios` (macOS)
or `make android`, then `make dev` as usual.

`make check` prints one `<gate>: N ... checked` line per gate and a final
tally. A gate whose tool is missing prints `SKIPPED` and the tally fails;
`BEARING_ALLOW_SKIP=1 make check` lets a laptop through and is never set in CI.
`make test-e2e` (Maestro) needs a simulator with the app installed and is
not part of `check`.

## Before the first build

- `android.package` and `ios.bundleIdentifier` in `app.json` derive from the
  repo name under `com.example`; change them if the app ships under another
  domain.
- `pnpm dlx eas-cli init` links the project and fills `extra.eas.projectId`;
  `pnpm dlx eas-cli update:configure` adds `updates.url`.
- `make build-preview` prints the EAS command and refuses without
  `EAS_CONFIRM=1`; builds are the engineer's call. CI's `build-android` and
  `build-ios` jobs run on EAS cloud from a Linux runner (no Mac needed) with
  the `preview` profile on `develop` and `production` on a tag.

## Over-the-air updates and rollback

`expo-updates` is configured in `app.json` (`updates.enabled`, check on
load, no cache fallback wait) and each EAS build profile pins a channel
(`development`, `preview`, `production`). `runtimeVersion` follows the app
version, so an update only reaches builds with the same native code.

- Ship JS to a channel: `eas update --channel preview --message "..."`
  (the manual `publish-update` CI job does this for `develop`).
- Roll back: `eas update:republish --channel production --group <id>`
  re-publishes a previous update group as the newest; `eas update:list
--channel production` shows the groups. A rollback to the embedded bundle
  is `eas update:roll-back-to-embedded --channel production`.
- A change to native code (new module, SDK bump) needs a new build and a
  new `runtimeVersion`; an update cannot carry it.

## Dependency audit

`make vuln` (`pnpm audit --audit-level high --prod`) blocks the pipeline.
`pnpm.overrides` in `package.json` lifts transitive fixes (postcss). On
SDK 57 (September 2026) no high advisory needs an ignore entry. If one is
ever added under `pnpm.auditConfig.ignoreGhsas`, it names an advisory with
no patched release and the date; never add an entry that has a patched
version.

## Layout

See `AGENTS.md` and the `react-native` skill for the conventions. `app/`
routes, `src/features/<feature>` owns api, schemas, hooks and components,
`src/lib` holds the api client, query client and secure store.
