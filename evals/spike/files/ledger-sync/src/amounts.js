// Amounts are integer paise held as BigInt; statements carry rupees as text.

export function parsePaise(text) {
  const m = /^(-)?(\d+)(?:\.(\d{1,2}))?$/.exec(String(text).trim().replaceAll(',', ''));
  if (!m) throw new Error(`not an amount: ${text}`);
  const paise = BigInt(m[2]) * 100n + BigInt((m[3] ?? '0').padEnd(2, '0'));
  return m[1] ? -paise : paise;
}

export function formatPaise(paise) {
  const neg = paise < 0n;
  const abs = neg ? -paise : paise;
  const rupees = (abs / 100n).toString();
  const frac = (abs % 100n).toString().padStart(2, '0');
  return `${neg ? '-' : ''}${rupees}.${frac}`;
}
