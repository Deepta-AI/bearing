// Money arrives from the API as integer paise. Never divide in a component;
// format here so every screen shows the same thing.
const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", minimumFractionDigits: 2 });

export function formatINR(amountPaise: number): string {
  if (!Number.isInteger(amountPaise)) throw new TypeError("amount must be integer paise");
  return inr.format(amountPaise / 100);
}

const dt = new Intl.DateTimeFormat("en-IN", { day: "numeric", month: "short", year: "numeric", timeZone: "Asia/Kolkata" });

export function formatDate(iso: string): string {
  return dt.format(new Date(iso));
}
