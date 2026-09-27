import { test } from 'node:test';
import assert from 'node:assert/strict';
import { placeOrder, cancelOrder } from '../src/orders.js';
import { fakeEmitter } from '../src/analytics.js';

function fakeDb() {
  const orders = [];
  return {
    orders,
    async countOrders(userId) {
      return orders.filter((o) => o.userId === userId).length;
    },
    async insertOrder(o) {
      const order = { id: `ord_${orders.length + 1}`, ...o };
      orders.push(order);
      return order;
    },
    async updateOrder(id, patch) {
      Object.assign(orders.find((o) => o.id === id), patch);
    },
  };
}

const cart = { lines: [{ sku: 'ATTA-5KG', qty: 1 }], totalMinor: 32900 };

test('the first order is tracked as a first order', async () => {
  const db = fakeDb();
  const analytics = fakeEmitter();
  await placeOrder(db, analytics, { userId: 'u1', cart, method: 'upi', requestId: 'r1' });
  await placeOrder(db, analytics, { userId: 'u1', cart, method: 'upi', requestId: 'r2' });
  assert.deepEqual(analytics.events.map((e) => e.props.is_first_order), [true, false]);
  assert.equal(analytics.events[0].props.value_minor, 32900);
});

test('an order can be cancelled with a known reason', async () => {
  const db = fakeDb();
  const order = await placeOrder(db, fakeEmitter(), { userId: 'u1', cart, method: 'cod', requestId: 'r1' });
  await cancelOrder(db, { orderId: order.id, reason: 'stock' });
  assert.equal(db.orders[0].status, 'cancelled');
  await assert.rejects(cancelOrder(db, { orderId: order.id, reason: 'bored' }));
});
