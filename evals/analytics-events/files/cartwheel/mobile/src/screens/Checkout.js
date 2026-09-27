import React, { useEffect, useState } from 'react';
import { View, Button } from 'react-native';
import * as analytics from '../analytics';
import { api } from '../api';

export default function Checkout({ navigation }) {
  const [method, setMethod] = useState('upi');
  useEffect(() => {
    analytics.screen('checkout');
  }, []);

  async function pay() {
    analytics.track('payment_submitted', { payment_method: method });
    const order = await api.post('/api/orders', { method });
    navigation.navigate('OrderConfirmation', { order });
  }

  return (
    <View>
      <Button title="UPI" onPress={() => setMethod('upi')} />
      <Button title="Card" onPress={() => setMethod('card')} />
      <Button title="Cash on delivery" onPress={() => setMethod('cod')} />
      <Button title="Place order" onPress={pay} />
    </View>
  );
}
