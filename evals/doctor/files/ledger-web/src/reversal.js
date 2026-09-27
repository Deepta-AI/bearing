// Reversing a journal entry: post the same lines with the sign flipped, so
// the original and its reversal net to zero line by line (LED-212).
export function reverseEntry(entry) {
  return {
    memo: `reversal of ${entry.id}`,
    reverses: entry.id,
    lines: entry.lines.map((l) => ({
      ...l,
      amountPaise: l.amountPaise > 0 ? -l.amountPaise : l.amountPaise,
    })),
  };
}
