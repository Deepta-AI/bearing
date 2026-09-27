# Checklist

Expo app for field teams: today's tasks, per-task notes, done and undo.
Runs on the Expo dev client (expo-dev-client), so JS-only changes ship
over EAS Update and anything native needs a new store build.

    pnpm install
    pnpm start          # expo start --dev-client
    pnpm test           # jest-expo

Motion and theme values live in src/theme.ts.
