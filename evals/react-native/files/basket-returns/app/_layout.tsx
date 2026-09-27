import { QueryClientProvider } from '@tanstack/react-query';
import * as ImagePicker from 'expo-image-picker';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { queryClient } from '@/lib/query-client';
import { useSession } from '@/lib/session';

/** Root layout: providers, then the stack. Restores the session once. */
export default function RootLayout() {
  const restore = useSession((s) => s.restore);

  useEffect(() => {
    restore().catch(() => undefined);
    // Ask up front so the returns flow never stops to prompt.
    ImagePicker.requestCameraPermissionsAsync().catch(() => undefined);
  }, [restore]);

  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <StatusBar style="auto" />
        <Stack screenOptions={{ headerShown: false }} />
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}
