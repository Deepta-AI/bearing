# Basket

Shared grocery lists for households. Expo (SDK 52) app for iOS and Android.

- `npx expo start` for local development
- Builds and store submissions go through EAS (`eas.json`); the release
  engineer runs `eas build` and `eas submit` from their own machine.
- Store listing text lives in `store/metadata/`, screenshots in
  `store/screenshots/`, privacy answers in `store/privacy/`.
- Each store release gets a record in `docs/releases/mobile/`.
