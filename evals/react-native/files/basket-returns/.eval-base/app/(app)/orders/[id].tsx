import { useLocalSearchParams } from 'expo-router';
import { ActivityIndicator, FlatList, StyleSheet, Text, View } from 'react-native';

import { ErrorState } from '@/components/ErrorState';
import { useOrder } from '@/features/orders/hooks';
import { orderIdSchema } from '@/features/orders/schemas';
import { errorMessage } from '@/lib/api';
import { formatMoney } from '@/lib/money';

/** One order: its lines and total. Opened from order history or a basket://orders/<id> link. */
export default function OrderDetailScreen() {
  const params = useLocalSearchParams<{ id: string }>();
  const parsed = orderIdSchema.safeParse(params.id);
  const id = parsed.success ? parsed.data : '';
  const query = useOrder(id, parsed.success);

  if (!parsed.success) return <ErrorState message="That order link is not valid." onRetry={() => undefined} />;
  if (query.isPending) return <ActivityIndicator accessibilityLabel="Loading order" />;
  if (query.isError) return <ErrorState message={errorMessage(query.error)} onRetry={() => void query.refetch()} />;

  const order = query.data;
  return (
    <FlatList
      data={order.lines}
      keyExtractor={(l) => l.sku}
      contentContainerStyle={styles.list}
      ListHeaderComponent={<Text style={styles.title}>Order {order.id}</Text>}
      renderItem={({ item }) => (
        <View style={styles.row}>
          <Text>
            {item.qty} x {item.name}
          </Text>
          <Text>{formatMoney(item.qty * item.unit_price_minor, 'INR')}</Text>
        </View>
      )}
      ListFooterComponent={<Text style={styles.total}>Total {formatMoney(order.total_minor, order.currency)}</Text>}
    />
  );
}

const styles = StyleSheet.create({
  list: { padding: 16, gap: 12 },
  title: { fontSize: 20, fontWeight: '700' },
  row: { flexDirection: 'row', justifyContent: 'space-between' },
  total: { fontSize: 18, fontWeight: '700', marginTop: 12 },
});
