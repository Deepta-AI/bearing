// Parses a bank statement CSV: date,ref,memo,amount (memo may be quoted).

export function parseStatement(text) {
  const rows = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('date,')) continue;
    const m = /^([^,]+),([^,]+),(?:"((?:[^"]|"")*)"|([^,]*)),(.+)$/.exec(line);
    if (!m) throw new Error(`bad statement line: ${line}`);
    rows.push({
      date: m[1],
      ref: m[2],
      memo: m[3] !== undefined ? m[3].replaceAll('""', '"') : m[4],
      amount: m[5],
    });
  }
  return rows;
}
