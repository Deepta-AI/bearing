import React, { useEffect } from 'react';
import { View, Text, Button } from 'react-native';
import * as analytics from '../analytics';
import { api } from '../api';

export default function Cart({ cart, navigation }) {
  useEffect(() => {
    analytics.screen('cart');
  }, []);

  async function applyCoupon(code) {
    const res = await api.post('/api/cart/coupon', { code });
    cart.discountMinor = res.discountMinor;
  }

  function checkout() {
    analytics.track('checkout_started', {
      cart_value_minor: cart.totalMinor,
      currency: 'INR',
      item_count: cart.lines.length,
    });
    navigation.navigate('Checkout');
  }

  return (
    <View>
      <Text>{cart.lines.length} items</Text>
      <Button title="Checkout" onPress={checkout} />
    </View>
  );
}
