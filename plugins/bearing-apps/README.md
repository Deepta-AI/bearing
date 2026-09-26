# bearing-apps

An optional plugin of the Bearing marketplace: stack conventions and
scaffold templates for apps.

## What it contains

`skills/`: 6 stack skills, each with its guidelines, review checklist and
repository templates:

- `react`: React web apps
- `nextjs`: Next.js apps
- `react-native`: React Native with Expo
- `flutter`: Flutter apps
- `ios`: native iOS
- `android`: native Android

Call them as `/bearing-apps:<name>`; the workflow skills in `bearing`
load them when a repository uses the stack.

## Install

Inside Claude Code:

```
/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing
/plugin install bearing-apps@bearing
```

`bearing` is required; this plugin needs it. `bearing-backend` and
`bearing-apps` are optional: install the ones your repositories use.

## More

Documentation, the installer and the source: <https://github.com/Deepta-AI/bearing>.
Licence: MIT (see `LICENSE`).
