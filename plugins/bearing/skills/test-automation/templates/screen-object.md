# Maestro screen pattern

Maestro has no classes, so a "screen object" is a folder of subflows with
one file per action, and a test flow that composes them. Locators are
`text` (the visible label) or `id` (the `testID` prop); never coordinates.

## Layout

```
.maestro/
  config.yaml                 # tags and the appId
  screens/
    login/
      open.yaml               # navigate to the screen and assert it is there
      submit.yaml             # fill and submit; takes EMAIL and PASSWORD
    dashboard/
      assert-loaded.yaml
  flows/
    tc-0001-valid-login.yaml  # one flow per TC, named with the id
```

## A screen subflow

`.maestro/screens/login/submit.yaml`:

```yaml
# Fills the login form and presses Sign in. Parameters: EMAIL, PASSWORD.
appId: __ORG_ID__.__REPO_NAME__
---
- tapOn:
    id: "login-email"
- inputText: ${EMAIL}
- tapOn:
    id: "login-password"
- inputText: ${PASSWORD}
- tapOn: "Sign in"
```

## A test flow

`.maestro/flows/tc-0001-valid-login.yaml`:

```yaml
# TC-0001 US-01-001 AC-US-01-001-1 Valid login reaches the dashboard
appId: __ORG_ID__.__REPO_NAME__
tags: [e2e, P1]
env:
  EMAIL: user@example.test
  PASSWORD: correct-horse
---
- launchApp:
    clearState: true
- runFlow: ../screens/login/open.yaml
- runFlow: ../screens/login/submit.yaml
- runFlow: ../screens/dashboard/assert-loaded.yaml
```

## Rules

- Line one of every flow is the TC id, the story id and the AC ids, so
  `traceability` finds it by grep.
- `extendedWaitUntil` with a `timeout`, never a fixed `- wait`.
- Every `testID` used here is also the element's `accessibilityLabel`
  fallback; add the label first, the id second.
- Run with `maestro test --include-tags P1 .maestro/flows`; quarantine is
  `--exclude-tags quarantine`.
