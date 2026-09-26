// Store the order and send the confirmation email. Returns the order id.
export async function placeOrder(db, mailer, customerEmail, items) {
  const total = items.reduce((sum, i) => sum + i.qty * i.pricePaise, 0);
  let orderId;
  db.exec('BEGIN');
  try {
    const res = db
      .prepare('INSERT INTO orders (customer_email, total_paise) VALUES (?, ?)')
      .run(customerEmail, total);
    orderId = Number(res.lastInsertRowid);
    const addItem = db.prepare('INSERT INTO order_items (order_id, sku, qty) VALUES (?, ?, ?)');
    for (const i of items) addItem.run(orderId, i.sku, i.qty);
    db.exec('COMMIT');
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }

  try {
    await mailer.sendConfirmation(orderId, customerEmail, total);
  } catch {
    // ignore, the order is saved
  }
  return orderId;
}
