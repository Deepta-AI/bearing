---
name: android
description: 'Conventions for native Android: Kotlin, Jetpack Compose, Material 3, Hilt, coroutines, Room, Retrofit, Gradle, ktlint, detekt. Use when writing, reviewing or scaffolding "Android", "Kotlin" or "Compose" code.'
allowed-tools: Read, Grep, Glob, Skill, Bash(./gradlew test:*), Bash(./gradlew lint:*), Bash(./gradlew ktlintCheck:*), Bash(./gradlew detekt:*), Bash(./gradlew assembleDebug:*), Bash(make:*)
---

# android

The Android stack on this standard: Kotlin 2.4, Gradle 9.7 with the Kotlin DSL and
`gradle/libs.versions.toml`, AGP 9.4, Jetpack Compose with Material 3, Hilt,
coroutines + Flow, Room, Retrofit + kotlinx.serialization, DataStore,
Keystore-backed token storage (Tink), ktlint + detekt, JUnit Jupiter (JUnit 6)
for unit tests and JUnit 4 + Compose test rules for instrumented tests.
minSdk 26, targetSdk and compileSdk 36 (Google Play requires target API 36
for new apps and updates from 31 August 2026), JDK 17.

## Inputs

- Kotlin and Java files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.kt`, `.kts` or `.java` files under an Android
  repository: apply `references/guidelines.md`. Read it once per session.
- Reviewing a diff with those files: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo android <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Pack skills

Google's android/skills pack covers the platform jobs below. When one is
installed, load it with the Skill tool for that job and
keep this lane's rules, catalog and gate around it. When it is not
installed, do the job from this lane's references and name the missing
skill in the report.

- `agp-9-upgrade`: leaving the built-in Kotlin and new DSL opt-outs (see
  Gotchas) and any AGP 9 build-script breakage. Its version floors (KSP
  2.3.6, Hilt 2.59.2) are met by the catalog. Bumps still land in
  `gradle/libs.versions.toml`, one per commit.
- `edge-to-edge`: insets, keyboard (IME) padding and system bar contrast
  on a new or changed screen. targetSdk 36 forces edge-to-edge, so any
  screen with a text field, a list or a bottom bar gets its checklist.
- `android-intent-security`: a manifest change, an exported component, a
  deep link, a `PendingIntent` or code that reads intent extras, when
  writing or reviewing. Its findings are reported under rule 6.
- `r8-analyzer`: release size, keep rules, or a crash only a release build
  shows. It reports and never edits; the fix is a narrow rule written here.
  Its AGP 9.3+ path calls Python scripts the pack does not ship (absent at
  the pinned commit); its R8-version path carries the scripts inline and
  needs Python with protobuf; else it falls to heuristics. Say which ran.
- `android-testing-setup`: adding a test layer the repository lacks
  (screenshot, Robolectric UI, Hilt test runner, coverage). Tell it the
  stack first: local tests are JUnit Jupiter (JUnit 6) through the
  android-junit plugin and instrumented tests are JUnit 4, so its JUnit 4
  default for local tests does not apply.
- `navigation-3`: only in a repository already on Navigation 3 or after an
  ADR moves to it. The default here stays Navigation Compose 2 with
  type-safe routes.

## Layout

```
app/                          one module to start; feature modules when a
                              second team or a build-time problem appears
app/src/main/java/com/example/app/
  App.kt                      @HiltAndroidApp, nothing else
  MainActivity.kt             setContent { AppTheme { AppNavHost() } }
  ui/<feature>/               Screen (stateless) + Route (collects) + ViewModel
  ui/theme/, ui/navigation/   Material 3 theme; type-safe NavHost routes
  domain/<feature>/           models and repository interfaces, no Android imports
  data/<feature>/             repository implementations, Room, mappers
  data/network/               Retrofit services, DTOs, NetworkModule
  di/                         Hilt modules that are not feature-owned
gradle/libs.versions.toml     every version pinned once
Makefile                      the only entry point: help setup dev check fix test doctor
```

The package is fixed at `com.example.app` so the skeleton compiles as scaffolded
(brg-scaffold slugs are kebab-case and cannot be a package). The README
documents the rename.

## On a foreign layout

Hard rules anywhere: 1 (one state stream per screen, in the pattern the
repository uses), 2, 4, 5, 6 and 8. Advisory: the directory layout,
Compose (existing View screens are not rewritten; new screens follow
the rule), Hilt (Koin or Dagger stay where they are), Room, the version
catalog and the Makefile targets: propose a switch in an ADR, never
inside a feature change. Say which rule was relaxed and why.

## Rules that matter most

1. Unidirectional data flow. A ViewModel exposes one `UiState` (a sealed
   interface) through a single `StateFlow`; the UI sends events as function
   calls. No LiveData in new code.
2. Coroutines run in `viewModelScope` or a lifecycle-aware scope. `GlobalScope`
   is a finding. Every dispatcher is injected (`@IoDispatcher`), never named
   inline. Never catch `CancellationException`.
3. Room is the only local source of truth. The repository merges network and
   Room; the UI observes Room, never a network response.
4. Retrofit DTOs stop at the repository. They are mapped to domain types there
   and never reach a ViewModel or a composable.
5. Tokens are stored only as ciphertext: a Tink AEAD whose keyset is wrapped
   by an Android Keystore key (`AndroidKeysetManager`), the ciphertext in
   DataStore. Never plaintext in DataStore or prefs, never a log.
   `EncryptedSharedPreferences` (security-crypto) is deprecated; do not add it,
   and migrate it when a change touches token storage.
6. No exported component beyond the launcher activity without a permission.
   Every deep link and intent extra is validated before use.
7. Compose: state hoisted to the Route, `remember` keys name every input,
   no side effects in composition, `LaunchedEffect` keys are the values that
   restart it. Every string and dimension comes from resources or the theme.
8. Java repositories: fields are `final`, `Optional` never in a field or
   parameter, no raw types, records (or AutoValue below API 34 desugaring)
   for values, `Executor`s injected, never `new Thread`.
9. `make check` = ktlint, detekt, Android lint, unit tests, `assembleDebug`.
   CI runs the same target.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (a plugin the repository has not applied is
skipped and named).

```
make setup    # wrapper jar (gradle wrapper), local.properties, git hooks
make dev      # how to open in Android Studio; installDebug if a device is attached
make check    # ./gradlew ktlintCheck detekt lint testDebugUnitTest assembleDebug
make fix      # ./gradlew ktlintFormat
make test     # ./gradlew testDebugUnitTest   make test-ui  # ./gradlew connectedDebugAndroidTest
make doctor   # java, ANDROID_HOME, wrapper, adb, hooksPath
```

## Gotchas

- The Gradle daemon needs `org.gradle.jvmargs=-Xmx3g` or the Kotlin compiler
  dies quietly on a 4 GB runner; the templates set it in `gradle.properties`.
- The configuration cache is on. A plugin that breaks it is run with
  `--no-configuration-cache` in its own job (the OWASP scan does), never by
  turning the cache off for everyone.
- kotlinx.serialization (1.5.0 and later) ships its own conditional R8
  rules, so `@Serializable` classes need no keep rule of ours. A
  package-wide `-keep class x.** { *; }` switches R8 off for that package
  (r8-analyzer ranks it the worst rule there is). Add a rule only for one
  class the bundled rules miss, such as a named companion object, after a
  release build shows the crash.
- Native libraries must be 16 KB page aligned for Play (targetSdk 35+);
  AGP 8.5.1+ aligns them, an old NDK dependency does not. `make lint` flags it.
- AGP 9 turns on built-in Kotlin and the new DSL. The template opts out
  (`android.builtInKotlin=false`, `android.newDsl=false` in
  `gradle.properties`) because detekt 1.23.8, the current stable, needs the
  kotlin-android plugin and the old DSL. AGP 10 removes both switches: move
  to a detekt release that supports AGP 9, then run the `agp-9-upgrade`
  skill (it drops the kotlin-android plugin and the two lines), then bump
  AGP.
- The signing keystore and its passwords never enter the repository. CI reads
  them from masked variables and writes the keystore to a temp path.
- Baseline profiles and Compose compiler metrics are opt-in tasks, not part of
  `make check`; run them before a release, read the numbers, commit the profile.
- The wrapper jar is binary, so the templates do not ship it. `make setup`
  generates it; commit `gradle/wrapper/gradle-wrapper.jar` once.
- ktlint reads `.editorconfig`; the stack template ships one because the shared
  repo templates do not.
