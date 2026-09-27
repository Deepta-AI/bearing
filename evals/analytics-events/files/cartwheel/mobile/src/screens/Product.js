import React, { useEffect } from 'react';
import { View, Text, Button } from 'react-native';
import * as analytics from '../analytics';
import { api } from '../api';

export default function Product({ product }) {
  useEffect(() => {
    analytics.screen('product');
    analytics.track('product_viewed', { product_id: product.id, category: product.category });
  }, [product.id]);

  async function add() {
    await api.post('/api/cart/lines', { productId: product.id, quantity: 1 });
    analytics.track('product_added_to_cart', {
      product_id: product.id,
      quantity: 1,
      price_minor: product.priceMinor,
      currency: 'INR',
    });
  }

  return (
    <View>
      <Text>{product.name}</Text>
      <Button title="Add" onPress={add} />
    </View>
  );
}
