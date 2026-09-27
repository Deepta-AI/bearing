import * as amplitude from '@amplitude/analytics-react-native';

const AMPLITUDE_KEY = process.env.EXPO_PUBLIC_AMPLITUDE_KEY ?? '';

export function initAnalytics(userId: string) {
  amplitude.init(AMPLITUDE_KEY, userId, {
    trackingOptions: { ipAddress: false },
  });
}

export function track(event: string, props: Record<string, unknown> = {}) {
  amplitude.track(event, props);
}
