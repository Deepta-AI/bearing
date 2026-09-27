import { Redirect, Stack } from 'expo-router';
import { ActivityIndicator, View } from 'react-native';

import { useSession } from '@/lib/session';

/** The auth gate: every route under app/(app) needs a signed-in customer. */
export default function SignedInLayout() {
  const status = useSession((s) => s.status);

  if (status === 'loading') {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator accessibilityLabel="Loading" />
      </View>
    );
  }
  if (status === 'signedOut') return <Redirect href="/sign-in" />;

  return <Stack />;
}
