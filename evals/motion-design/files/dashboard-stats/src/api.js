// Today's figures. Conversion is null until the analytics export for the day
// has landed (usually mid-morning), so the card shows "n/a" until then.

export async function fetchStats() {
  const res = await fetch("/api/stats/today", { headers: { accept: "application/json" } });
  if (!res.ok) throw new Error(`stats: ${res.status}`);
  return res.json();
}

// Shape, for reference and the tests:
export const SAMPLE = {
  revenue: 124500.5,
  orders: 1284,
  conversion: null,
  refundRate: 0.0213,
  updatedAt: "2026-09-26T09:30:00+05:30",
};
