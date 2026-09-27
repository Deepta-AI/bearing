import React, { useEffect } from 'react';
import { View, Text } from 'react-native';
import * as analytics from '../analytics';

export default function OrderConfirmation({ route }) {
  const { order } = route.params;
  useEffect(() => {
    analytics.screen('order_confirmation');
    analytics.track('purchase_completed', { order_id: order.id, value_minor: order.totalMinor, currency: 'INR' });
  }, [order.id]);

  return (
    <View>
      <Text>Order {order.id} placed</Text>
    </View>
  );
}
