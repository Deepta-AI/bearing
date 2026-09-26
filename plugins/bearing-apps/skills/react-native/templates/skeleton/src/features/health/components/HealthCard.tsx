import { ActivityIndicator, Pressable, Text, View } from 'react-native';

import { ApiError } from '@/lib/api';

import type { Health } from '../schemas';

type Props = {
  status: 'pending' | 'error' | 'success';
  data: Health | undefined;
  error: unknown;
  onRetry: () => void;
};

/** Map an error to copy once, here. The raw message never reaches a Text. */
function errorCopy(error: unknown): string {
  if (error instanceof ApiError) return `The API answered ${error.status}.`;
  return 'Could not reach the API.';
}

/** Shows the API health in its loading, error, empty and data states. */
export function HealthCard({ status, data, error, onRetry }: Props) {
  return (
    <View
      testID="health-card"
      className="rounded-2xl border border-border p-4 dark:border-border-dark"
    >
      {status === 'pending' && (
        <View className="flex-row items-center gap-3">
          <ActivityIndicator accessibilityLabel="Loading" />
          <Text className="text-muted-foreground">Checking the API</Text>
        </View>
      )}
      {status === 'error' && (
        <View className="gap-3">
          <Text className="text-destructive">{errorCopy(error)}</Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Retry health check"
            onPress={onRetry}
            hitSlop={8}
            className="self-start rounded-lg bg-primary px-4 py-2 active:bg-primary-pressed"
          >
            <Text className="text-primary-foreground">Retry</Text>
          </Pressable>
        </View>
      )}
      {status === 'success' && !data && (
        <Text className="text-muted-foreground">No health data yet.</Text>
      )}
      {status === 'success' && data && (
        <Text className="text-foreground dark:text-foreground-dark">
          API {data.status}
          {data.version ? ` (v${data.version})` : ''}
        </Text>
      )}
    </View>
  );
}
