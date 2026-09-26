# __REPO_NAME__

Android app (Kotlin, Compose, Hilt). `make help` lists every command;
`make check` is the gate.

## Run

```
cp .env.example .env
make setup          # verifies the committed wrapper jar, writes local.properties, git hooks
make doctor         # JDK 17 and ANDROID_HOME must both be present
make dev            # prints how to open in Android Studio; installDebug if a device is attached
```

Open the folder in Android Studio (a release that supports AGP 9.4, bundled
JDK 17). The first sync downloads platform 36 if the SDK does not have it.

`make check` runs ktlint, detekt, Android lint (severities in `lint.xml`,
any error fails), the JVM unit tests and `assembleDebug`, printing one
`<gate>: N ... checked` line each and a final tally. Without a JDK every
gate prints `SKIPPED` and the tally fails; `BEARING_ALLOW_SKIP=1 make check`
lets a laptop through and is never set in CI. `make test-ui` needs an
emulator or device and is not part of `check`.

## Gradle wrapper

`gradlew` and `gradle/wrapper/gradle-wrapper.jar` are committed; they are
the files Gradle publishes for the version in
`gradle/wrapper/gradle-wrapper.properties` (9.7.1). After bumping that
version, `make bootstrap` downloads the matching jar and verifies it
against the sha256 Gradle publishes at services.gradle.org; commit the
result. CI's `wrapper` job repeats the checksum on every pipeline.

## Rename the package

The skeleton ships as `com.example.app` so it compiles as scaffolded (the
brg-scaffold slug is kebab-case and cannot be a Java package). To rename:

1. In Android Studio, right-click `com.example.app` under `app/src/main/java`,
   Refactor > Rename, and let it move all three source sets.
2. Change `namespace` and `applicationId` in `app/build.gradle.kts`.
3. Update `--package_name` in the `deploy-internal` CI job.
4. `make check`.

## Configuration

`BuildConfig.API_BASE_URL` comes from the `API_BASE_URL` Gradle property or
environment variable (`.env` is exported by `make dev`). Nothing else is
configured at build time; runtime settings live in DataStore, tokens in
Keystore-backed storage. ktlint reads its rules from the `[*.{kt,kts}]`
section of `.editorconfig`; detekt from `detekt.yml`.

## Signing and release

No keystore, password or `local.properties` is ever committed (the pre-commit
hook rejects them). The `publish` CI job is manual and reads four masked
variables: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. `app/build.gradle.kts` picks
them up through `ANDROID_KEYSTORE_PATH` and friends; without them a release
build is unsigned. `deploy-internal` prints the fastlane supply wiring for
the Play internal track and fails until it is replaced.

## Layout

See `AGENTS.md` and the `android` skill for the conventions. `ui/`
renders, `domain/` decides, `data/` fetches and stores, `di/` wires.
Instrumented tests are JUnit 4 (the AndroidX runner and Compose rules are
JUnit 4); unit tests are JUnit Jupiter (JUnit 6).
