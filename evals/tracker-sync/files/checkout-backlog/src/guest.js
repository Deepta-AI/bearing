// Guest checkout: an order placed without an account carries a contact email
// (SHOP-41) and can be looked up later by email plus order number (SHOP-42).
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function startGuestOrder({ email, items }) {
  if (!EMAIL.test(email || "")) throw new Error("a valid email is required");
  if (!Array.isArray(items) || items.length === 0) throw new Error("cart is empty");
  return { kind: "guest", email: email.trim().toLowerCase(), items };
}

export function findGuestOrder(orders, { email, orderNo }) {
  const want = (email || "").trim().toLowerCase();
  return orders.find((o) => o.kind === "guest" && o.email === want && o.orderNo === orderNo) || null;
}
