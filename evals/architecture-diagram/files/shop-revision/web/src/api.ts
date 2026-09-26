const token = () => localStorage.getItem("session") ?? "";

export async function placeOrder(cartId: string, paymentId: string) {
  const res = await fetch("/api/orders", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token()}` },
    body: JSON.stringify({ cart_id: cartId, payment_id: paymentId }),
  });
  if (!res.ok) throw new Error(`order failed: ${res.status}`);
  return res.json();
}

export async function getOrder(id: string) {
  const res = await fetch(`/api/orders/${id}`, {
    headers: { Authorization: `Bearer ${token()}` },
  });
  if (!res.ok) throw new Error(`not found: ${res.status}`);
  return res.json();
}
