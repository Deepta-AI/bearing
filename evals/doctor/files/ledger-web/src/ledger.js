// Double-entry postings: every journal entry must balance to zero.
export function balance(lines) {
  return lines.reduce((sum, l) => sum + l.amountPaise, 0);
}

export function validateEntry(entry) {
  if (!Array.isArray(entry.lines) || entry.lines.length < 2) {
    return { ok: false, error: "an entry needs at least two lines" };
  }
  if (entry.lines.some((l) => !Number.isInteger(l.amountPaise))) {
    return { ok: false, error: "amounts are integer paise" };
  }
  if (balance(entry.lines) !== 0) {
    return { ok: false, error: "entry does not balance" };
  }
  return { ok: true };
}
