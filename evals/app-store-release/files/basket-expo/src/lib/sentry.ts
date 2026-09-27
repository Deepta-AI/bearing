import * as Sentry from '@sentry/react-native';

export function initSentry(userId: string) {
  Sentry.init({
    dsn: process.env.EXPO_PUBLIC_SENTRY_DSN,
    tracesSampleRate: 0.2,
  });
  Sentry.setUser({ id: userId });
}
