# react-native: Pack skills and when to load them

Read when the task is an Expo SDK bump, native navigation UI, or a dev client.

- `expo-upgrade`: an Expo SDK bump, or replacing a package Expo has
  deprecated (expo-av, AsyncStorage, direct `@react-navigation/*`
  imports). Its version floors win over this lane's pins; the gate after
  it is `make check` then `make doctor`. Its prebuild and cache steps
  apply only where `ios/` and `android/` are committed.
- `expo-router`: native navigation UI (stack headers, modals, form sheets,
  NativeTabs, link previews and menus) and the SDK 56+ rule to import
  from `expo-router/react-navigation`, never `@react-navigation/*`. Rule 5
  still holds. Route files under `app/` are URLs and follow expo-router's
  kebab-case (`app/order-history.tsx`); component files everywhere else
  keep this lane's naming, the component's name.
- `expo-dev-client` is not loaded: its commands are EAS cloud builds, some
  submitting to TestFlight, which the repository settings deny and which
  are the engineer's call. A local dev client comes from `make ios` or
  `make android`.
