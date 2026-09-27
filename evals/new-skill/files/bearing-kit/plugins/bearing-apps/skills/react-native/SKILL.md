---
name: react-native
description: 'React Native house rules: Expo, TypeScript strict, expo-router, React Query and Jest tests. Use when writing "a React Native screen", "an Expo app" or changing any React Native code.'
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(pnpm test:*), Bash(pnpm exec tsc:*)
---

# react-native

Conventions for React Native apps built with Expo.

## Inputs

- App root: the folder with `app.json`; if several, the one named in the
  request.

## Steps

1. Use the router, data layer and test setup the app already has.
2. New screens go under `app/` with a Jest test beside them.

## Output contract

```
Files: <paths>   Tests: pnpm test (N passed) | not run
```

## Gotchas

- Expo SDK upgrades go through their own change, never inside a feature.
