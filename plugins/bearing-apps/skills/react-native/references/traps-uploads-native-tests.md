# react-native: traps in uploads, native changes and tests

Read when the task uploads files, adds a native module, ships an update, or writes tests for a hook or screen.

- Files go to a presigned URL the API issues; the app never holds a
  storage key or signing secret, never builds a bucket URL, and sends the
  server's upload id back, not a key it made up. `Date.now()` in a key
  collides under `Promise.all`.
- Camera photos at `quality: 1` are often over 5 MB. Resize (expo-image-
  manipulator when installed) or lower `quality`, then check the size
  (`asset.fileSize` can be undefined; stat the file) against the server's
  limit before asking for the URL.

- A new native module (expo-image-picker, MMKV, anything with a config
  plugin) needs its plugin entry and usage strings in `app.json`; iOS
  terminates the app the first time the camera or library is opened
  without `NSCameraUsageDescription` or `NSPhotoLibraryUsageDescription`.
- With expo-updates and `runtimeVersion: { policy: "appVersion" }`, a new
  native module under an unchanged `version` lets an `eas update` reach
  binaries that lack it: the import throws, at launch when it sits in a
  layout. Bump `version` (or use the `fingerprint` policy) and ship a
  store build before any update that needs it.

- A test of a schema or a URL helper does not test the feature. Test the
  hook with `renderHook` and a fresh `QueryClient` (`retry: false`) with
  the `api.ts` module mocked (next page requested with the cursor, stops
  at null), and the screen with Testing Library (rows render, an invalid
  id shows the error and calls nothing).
