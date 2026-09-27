import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';

import { ErrorState } from '@/components/ErrorState';
import { fetchAddresses } from '@/features/addresses/api';
import type { Address } from '@/features/addresses/schemas';
import { errorMessage } from '@/lib/api';

/** The customer's saved delivery addresses (at most 10). */
export default function Addresses() {
  const query = useQuery({ queryKey: ['addresses'], queryFn: fetchAddresses });
  const [addresses, setAddresses] = useState<Address[]>([]);

  useEffect(() => {
    if (query.data) setAddresses(query.data);
  }, [query.data]);

  if (query.isPending) return <ActivityIndicator accessibilityLabel="Loading addresses" />;
  if (query.isError) return <ErrorState message={errorMessage(query.error)} onRetry={() => void query.refetch()} />;

  return (
    <ScrollView contentContainerStyle={styles.list}>
      {addresses.map((a) => (
        <View key={a.id} style={styles.row}>
          <Text style={styles.label}>{a.label}</Text>
          <Text>
            {a.line1}, {a.city} {a.pincode}
          </Text>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  list: { padding: 16, gap: 12 },
  row: { gap: 4 },
  label: { fontWeight: '600' },
});
