# Store listing: <app> v<X.Y.Z> (build <n>)

<!-- Template guidance: one store submission, written to
     docs/releases/mobile/<version>.md: the numbers the stores reject on, the
     listing, the rollout and its halt, and every command for the engineer,
     who alone holds the store credentials. Every comment says what goes
     there (What), what a strong entry has (Good) and an example (Example).
     Delete each comment when you fill its section. -->

Prepared: <YYYY-MM-DD>   Platform: ios | android | both   Track: <track>
Last accepted build: ios <n> | android <n> | unconfirmed

## Version checks

<!-- What: the version and build number checks, each with its values and
     result.
     Good: values are read from the files (project.yml, build.gradle.kts,
     app.json) and the last accepted build; a FAIL names the field and file
     to change, and stops the run. Android versionCode must beat every
     track, not only production.
     Example: "build number above last accepted | 412 > 409 | ok" -->

| Check | Value | Result |
| --- | --- | --- |
| version above last accepted | <X.Y.Z> > <prev> | ok | FAIL |
| build number above last accepted | <n> > <prev> | ok | FAIL |
| iOS build unique within version | | ok | FAIL | n/a |
| Android versionCode above every track | | ok | FAIL | n/a |

## iOS preflight

<!-- What: the four checks App Store validation rejects an upload on, each
     read from the repository, with the file to change when it fails; the
     section says "n/a (android)" for an Android-only release.
     Good: the icon check quotes `file <icon>.png` (1024 x 1024, no alpha);
     the privacy manifest counts required-reason API categories used in the
     app's sources against those declared in PrivacyInfo.xcprivacy; export
     compliance names where ITSAppUsesNonExemptEncryption is set; any
     failure stops the run before the commands.
     Example: "privacy manifest | 3 used, 2 declared (missing: UserDefaults)
     | FAIL: App/PrivacyInfo.xcprivacy" -->

| Check | Evidence | Result |
| --- | --- | --- |
| marketing icon 1024 x 1024, no alpha | | ok | FAIL | n/a |
| privacy manifest: required-reason APIs declared | <U> used, <D> declared | ok | FAIL | n/a |
| export compliance set | <file> | ok | FAIL | n/a |
| usage string for every privacy-gated framework | | ok | FAIL | n/a |

## Listing fields

<!-- What: every store listing field, one column per store, with the file
     it came from.
     Good: each value fits its character limit and is copied from the
     metadata directories, not written fresh; an empty field stays empty and
     is counted in the Filled line.
     Example: "Subtitle (30) / Short description (80) | Lab reports, filed
     for you | Match lab reports to patients in one tap |
     fastlane/metadata/en-GB/" -->

| Field | App Store Connect | Google Play | Source |
| --- | --- | --- | --- |
| Name (30 chars) | | | fastlane/metadata/... |
| Subtitle (30) / Short description (80) | | | |
| Description (4000) | | | |
| Keywords (100, iOS only) | | n/a | |
| Category | | | |
| Age rating / Content rating questionnaire | | | |
| Support URL | | | |
| Privacy policy URL | | | |
| Marketing URL (optional) | | n/a | |
| Contact email and phone | | | |
| Copyright | | n/a | |

Filled: <k> of <n>.

## Screenshots

<!-- What: required against present screenshots per device class, with the
     directory.
     Good: counts come from the screenshot directories; a device class the
     app does not support is marked n/a, not left blank.
     Example: "iPhone 6.9 inch | 3 to 10 | 5 | fastlane/screenshots/en-GB/" -->

| Device class | Required | Present | Path |
| --- | --- | --- | --- |
| iPhone 6.9 inch | 3 to 10 | | |
| iPhone 6.5 inch | 3 to 10 | | |
| iPad 13 inch (if supported) | 3 to 10 | | |
| Android phone | 2 to 8 | | |
| Android 7 inch tablet (if supported) | up to 8 | | |
| Android 10 inch tablet (if supported) | up to 8 | | |
| Feature graphic 1024x500 (Play) | 1 | | |

## Privacy

<!-- What: one row per SDK found with the data it collects, then the counts
     for the App Privacy labels and the Data safety form.
     Good: answers are derived from the SDKs found in the manifests and lock
     files and must match what each SDK does; what cannot be confirmed is
     unknown and counted, never "no".
     Example: "FirebaseAnalytics | app interactions, device id | yes | no |
     UserDefaults (CA92.1)" -->

| SDK | Data types | Linked to user | Tracking | Required reason API |
| --- | --- | --- | --- | --- |
| <sdk> | <types> | yes | no | unknown | yes | no | <api or n/a> |

App Privacy labels: <answered> of <items>. Data safety form: <answered> of <items>. Unknown: <k>.

## Rollout

<!-- What: the track this build goes to, the phasing, what halts it and who
     halts it.
     Good: production only after a green internal build with the same
     number; each halt criterion names its dashboard (crash-free users under
     99.5 percent or 0.3 below the last release, a new top-five crash
     cluster, API errors over the SLO, a one-star spike).
     Example: "- Halt criteria: crash-free users under 99.5% in the
     Crashlytics release view; Android halt in the Play Console" -->

- Track: <TestFlight internal | external | Play internal | closed | open | production>
- Phase: ios 7-day phased | android staged at <p>%
- Halt criteria: <list, each with the dashboard>
- Who halts: <rotation>

## Release notes (<chars> chars)

<!-- What: the user-facing notes for this version, with the character count
     in the heading.
     Good: under 4000 characters for iOS and 500 for Play; no ticket ids;
     never a feature that ships behind a flag, since reviewers look for it.
     Example: "Reports from your lab now file themselves against the right
     patient. Fixed a crash when opening large PDFs." -->

<user-facing text>

## Commands (for the engineer, never run here)

<!-- What: the build, upload and rollout commands the repository supports,
     one per line, in order.
     Good: each upload sits behind the uploads.log guard; when the build's
     key is already in the log the command is withheld and the engineer
     checks the store first. Placeholders in angle brackets when no lane
     exists.
     Example: "grep -qx 'ios.upload.com.example.app.412' docs/releases/
     mobile/uploads.log || { echo '<key>' >> <log> && <upload lane>; }" -->

```
<one per line>
```

## Review history

<!-- What: one row per store review outcome, added on every rejection.
     Good: the guideline number from the rejection text, the fix from the
     rejection playbook, and whether it needed a new build or a reply only.
     Example: "2026-09-26 | 412 | rejected | 5.1.1 | added account deletion
     in Settings; new build 413" -->

| Date | Build | Outcome | Guideline | Action |
| --- | --- | --- | --- | --- |
