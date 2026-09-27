export function onProductOpen(analytics, product) {
  analytics.track('product_viewed', { product_id: product.id, category: product.category });
}

export async function addToCart(api, analytics, product, quantity) {
  await api.post('/api/cart/lines', { productId: product.id, quantity });
  analytics.track('product_added_to_cart', {
    product_id: product.id,
    quantity,
    price_minor: product.priceMinor,
    currency: 'INR',
  });
}

export async function addToWishlist(api, product) {
  await api.post('/api/wishlist', { productId: product.id });
  // analytics.track('wishlist_added', { product_id: product.id });  // waiting on the sheet
}
