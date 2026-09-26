---
name: app-store-release
description: 'Prepares an App Store or Google Play submission: build numbers, listing, screenshots, privacy forms, phased rollout, rejection fixes. Use when asked to "submit to the App Store", "TestFlight" or "app rejected".'
argument-hint: "[ios|android|both] [vX.Y.Z] [--rejected]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(git tag -l:*), Bash(git describe:*), Bash(git log:*), Bash(date:*), Bash(fastlane lanes:*), Bash(file:*)
---

# app-store-release

A store submission is a release plus a review by a stranger. This skill
checks the numbers the stores reject on, fills what the listing needs,
plans the rollout and its halt, and prints every upload command for the
engineer to run.

Not this: `release` bumps the version and writes the CHANGELOG;
`bearing-apps:ios`, `bearing-apps:android` and `bearing-apps:react-native`
hold the build rules.

## Inputs

- platform: `$1`; if absent, detected: `project.yml` or `*.xcodeproj`
  (ios), `app/build.gradle.kts` (android), `app.json` with `expo`
  (both); none: ask once.
- version: `$2`; if absent, `MARKETING_VERSION` in `project.yml`,
  `versionName` in `app/build.gradle.kts`, `expo.version` in `app.json`;
  if absent, `git describe --tags --abbrev=0`; if absent, ask once.
- build number: `CURRENT_PROJECT_VERSION`, `versionCode`,
  `expo.ios.buildNumber` and `expo.android.versionCode`. Last accepted
  build: `docs/releases/mobile/<previous>.md`; if absent, ask once
  ("last build number the store accepted?"); unknown: `unconfirmed`.
- listing metadata: `fastlane/metadata/`, `store/`; if absent, every
  field is written empty and counted.
- screenshots: `fastlane/screenshots/`, `store/screenshots/`; if absent,
  the required list is printed with zero present.
- privacy inputs: `PrivacyInfo.xcprivacy`, the SDK list from
  `Package.swift`, `Podfile.lock`, `gradle/libs.versions.toml`,
  `package.json`; if absent, the privacy items are `unknown` and counted.
- release notes: the version's section in `CHANGELOG.md`; if absent,
  `git log --format=%s <last tag>..HEAD`, user-facing lines only.
- rollout tooling: `fastlane/Fastfile` (`fastlane lanes`), `eas.json`
  submit profiles; if absent, raw commands with placeholders.
- rejection text for `--rejected`: pasted by the user; if absent, ask once.
- templates and references in this skill: `templates/store-listing.md`,
  `references/rejection-playbook.md`.

## Steps

1. Resolve platform, version and build number. Checks: version is semver
   and above the last accepted; build number strictly above the last
   accepted; iOS build number unique within the version; Android
   `versionCode` above every track, not only production. Print "N
   version checks, K failed". Any failure stops with the field and file
   to change (`release` bumps them).
2. iOS preflight (ios and both), the checks App Store validation rejects
   an upload on, each read from the repository:
   - Marketing icon: the `AppIcon.appiconset/Contents.json` under the
     app's `*.xcassets` (Expo: `expo.icon` in `app.json`) names a
     1024x1024 image and that file exists; `file <icon>.png` must say
     `1024 x 1024` and must not say `RGBA` (the store refuses alpha on
     the marketing icon).
   - Privacy manifest: a `PrivacyInfo.xcprivacy` in the app target (not
     only in `Pods/`). Grep the app's sources for the required-reason
     APIs (`UserDefaults`, file timestamps such as `creationDate`,
     `modificationDate` and `attributesOfItem`, `systemUptime` and
     `mach_absolute_time`, disk space such as
     `volumeAvailableCapacity`, `activeInputModes`); each category used
     needs an `NSPrivacyAccessedAPITypes` entry with a reason. Count
     used against declared.
   - Export compliance: `ITSAppUsesNonExemptEncryption` in `Info.plist`,
     in `project.yml` info properties, or
     `ios.config.usesNonExemptEncryption` in `app.json`. Absent, every
     build waits on the compliance question in App Store Connect.
     `false` only when the app uses no encryption beyond HTTPS and the
     OS's own; anything else is `true` with the export documentation, a
     question for the engineer.
   - Usage strings: each privacy-gated framework the code imports
     (camera, microphone, photos, location, contacts, tracking) has its
     `NS...UsageDescription` in `Info.plist`, written for a user.
   Print "iOS preflight: N checks, K failed" with the file to change for
   each failure. Any failure stops before the commands in step 9.
3. Write `docs/releases/mobile/<version>.md` from
   `templates/store-listing.md`: one column per store, every listing
   field filled from the metadata directories. Print filled of total.
4. Screenshots: iOS 6.9 inch and 6.5 inch iPhone, 13 inch iPad when the
   app supports iPad; Android phone (at least two, 16:9 or 9:16), 7 and
   10 inch tablet when supported, feature graphic 1024x500. Count present
   against required from the screenshot directories.
5. Tracks: iOS TestFlight internal (up to 100 testers, no review) then
   external (review, up to 10,000); Android internal testing then closed,
   open, production. Name the track this build goes to. Production only
   after a green internal build with the same build number.
6. Phased rollout: iOS phased release over 7 days (1, 2, 5, 10, 20, 50,
   100 percent); Android staged rollout starting at 5 or 10 percent.
   Halt criteria, each with the dashboard to read: crash-free users
   under 99.5 percent or 0.3 below the previous release, a new crash
   cluster in the top five, API error rate over the SLO, a one-star
   review spike. Who halts and how: iOS pause in App Store Connect;
   Android halt in the Play Console or `fastlane supply --rollout`.
7. Privacy: App Privacy labels and the Play Data safety form as a list
   of answers derived from the SDKs found (each SDK with the data types
   it collects, linked or not, used for tracking or not); required
   reason APIs in `PrivacyInfo.xcprivacy`. Count answered and unknown.
8. Release notes: user-facing, no ticket ids; under 4000 characters for
   iOS and 500 for Play; never mention a feature that ships dark.
9. Print, never run, the commands the repository supports: `fastlane
   ios beta`, `fastlane ios release`, `fastlane android internal`,
   `fastlane supply --track production --rollout 0.1`, `eas build
   --platform <p> --profile production`, `eas submit --platform <p>
   --latest`. Placeholders in angle brackets when no lane exists.
   Uploads are guarded against a repeat. Read
   `docs/releases/mobile/uploads.log` (one key per line:
   `<ios|android>.upload.<bundle id>.<build>`, committed so the whole
   team sees it). When this build's key is already there, the upload
   command is not printed: the build is possibly uploaded, and the
   engineer checks App Store Connect or the Play Console for it first.
   Otherwise each upload command is printed behind the log, which is
   written before the upload so a crash mid-upload still counts:
   `grep -qx '<key>' docs/releases/mobile/uploads.log || { echo '<key>' >> docs/releases/mobile/uploads.log && fastlane ios beta; }`.
   A build that failed before reaching the store gets a new build
   number, never a deleted log line.
10. `--rejected`: match the pasted text to `references/rejection-playbook.md`
   by guideline number or phrase, print the fix and the reply, add a
   Review history row to the release doc, and say whether a new build
   is needed or a reply suffices.

## Output contract

```
## Mobile release: <platform> v<X.Y.Z> (build <n>)
Version checks: N run, K failed
iOS preflight: N checks, K failed (icon 1024 without alpha, privacy manifest U of D reasons, export compliance, usage strings) | n/a (android)
Listing: <filled> of <fields> (docs/releases/mobile/<version>.md)
Screenshots: <present> of <required> (missing: <list>)
Privacy: <answered> of <items>, <unknown> unknown (SDKs found: N)
Release notes: <chars> chars (limits: ios 4000, play 500)
Track: TestFlight internal | external | Play internal | closed | production at <p>%
Halt on: <criteria>
Commands for the engineer:
  <one per line, never run here; uploads behind the uploads.log guard>
Upload log: docs/releases/mobile/uploads.log (<key> new | already present: check the store, command withheld)
Rejection: <guideline> -> <fix>; new build | reply only         (--rejected only)
```

## Gotchas

- Never runs upload, submit or rollout commands; the store credentials
  are the engineer's and never enter the conversation.
- Android `versionCode` never goes down on any track, hotfix included;
  a wrong bump burns the number for good.
- An iOS build number reused within the same version is rejected at
  upload, not at review; check before the build, not after.
- A second upload of the same build after a timeout is the usual way a
  build number gets burned or a TestFlight group gets two builds. The
  uploads.log key is written before the upload runs, so a retry after a
  crash stops at the log; the store is checked before anyone clears it.
- The icon, the privacy manifest and the export-compliance key are
  checked at upload, not at review; a missing one costs a build number
  and an hour. Third-party SDKs on Apple's required-reason list ship
  their own `PrivacyInfo.xcprivacy`; an old SDK version without one is
  a dependency bump (`dependency-audit`), not an app manifest entry.
- A paused iOS phased release still reaches users who update by hand;
  a real halt is a new build with the fix.
- Data safety answers must match what the bundled SDKs do; an analytics
  SDK with "no data collected" is a listing removal, not a rejection.
- Release notes are read by reviewers; naming a flagged-off feature
  invites "feature not found".
- Review takes one to two days; expedited review is a request the
  store may refuse, never a lane.
