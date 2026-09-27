export async function placeOrder(db, analytics, { userId, cart, method, requestId }) {
  const previous = await db.countOrders(userId);
  const order = await db.insertOrder({ userId, lines: cart.lines, totalMinor: cart.totalMinor, method });
  analytics.track(
    'order_placed',
    { order_id: order.id, value_minor: order.totalMinor, currency: 'INR', is_first_order: previous === 0 },
    { userId, requestId },
  );
  return order;
}

export async function cancelOrder(db, { orderId, reason }) {
  if (!['customer', 'stock', 'payment'].includes(reason)) throw new Error(`bad reason ${reason}`);
  await db.updateOrder(orderId, { status: 'cancelled', cancelReason: reason });
}
