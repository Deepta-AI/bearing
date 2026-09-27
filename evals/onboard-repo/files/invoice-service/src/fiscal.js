// The Indian financial year (April to March) an invoice falls in, as "2025-26".
export function financialYear(issuedAt) {
  const d = new Date(issuedAt);
  const start = d.getMonth() >= 3 ? d.getFullYear() : d.getFullYear() - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, "0")}`;
}
