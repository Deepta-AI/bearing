import { Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { HealthCard } from '@/features/health/components/HealthCard';
import { useHealth } from '@/features/health/hooks';

/** Home screen: shows whether the API is reachable. Replace with the first real screen. */
export default function HomeScreen() {
  const health = useHealth();
  return (
    <SafeAreaView className="flex-1 bg-background dark:bg-background-dark">
      <View className="flex-1 gap-4 px-4 pt-6">
        <Text
          className="text-2xl font-semibold text-foreground dark:text-foreground-dark"
          accessibilityRole="header"
        >
          __REPO_NAME__
        </Text>
        <HealthCard
          status={health.status}
          data={health.data}
          error={health.error}
          onRetry={() => void health.refetch()}
        />
      </View>
    </SafeAreaView>
  );
}
