import { Stack } from 'expo-router';
import { useEffect } from 'react';
import { initAnalytics } from '../lib/analytics';
import { initSentry } from '../lib/sentry';
import { useAccount } from '../lib/account';

export default function RootLayout() {
  const account = useAccount();
  useEffect(() => {
    if (!account) return;
    initSentry(account.id);
    initAnalytics(account.id);
  }, [account]);
  return <Stack />;
}
