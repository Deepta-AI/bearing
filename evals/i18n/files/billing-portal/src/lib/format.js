// Display helpers. Amounts are paise (integer minor units) from the API.

export function formatMoney(paise) {
  return 'Rs. ' + (paise / 100).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export function formatDate(iso) {
  const d = new Date(iso);
  const dd = String(d.getUTCDate()).padStart(2, '0');
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${dd}/${mm}/${d.getUTCFullYear()}`;
}

export function overdueLabel(n) {
  return `${n} invoice${n === 1 ? '' : 's'} overdue`;
}

export function daysUntil(iso, now) {
  const ms = new Date(iso).getTime() - now.getTime();
  return Math.ceil(ms / 86400000);
}
