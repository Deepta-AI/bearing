import { router, useLocalSearchParams } from 'expo-router';
import { ActivityIndicator, FlatList, Pressable, StyleSheet, Text, View } from 'react-native';

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
      ListFooterComponent={
        <View style={styles.footer}>
          <Text style={styles.total}>Total {formatMoney(order.total_minor, order.currency)}</Text>
          {order.status === 'delivered' ? (
            <Pressable
              accessibilityRole="button"
              onPress={() => router.push({ pathname: '/returns/new', params: { orderId: order.id } })}
              style={styles.button}
            >
              <Text style={styles.buttonText}>Return items</Text>
            </Pressable>
          ) : null}
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  list: { padding: 16, gap: 12 },
  title: { fontSize: 20, fontWeight: '700' },
  row: { flexDirection: 'row', justifyContent: 'space-between' },
  footer: { marginTop: 12, gap: 16 },
  total: { fontSize: 18, fontWeight: '700' },
  button: { minHeight: 44, borderRadius: 8, borderWidth: 1, borderColor: '#1f6f43', justifyContent: 'center', alignItems: 'center' },
  buttonText: { color: '#1f6f43', fontSize: 16, fontWeight: '600' },
});
