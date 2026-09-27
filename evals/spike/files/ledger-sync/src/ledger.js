import { parsePaise } from './amounts.js';

export function ledger(db) {
  const insertEntry = db.prepare(
    'INSERT INTO entries (posted_on, memo, source_ref) VALUES (@postedOn, @memo, @sourceRef)',
  );
  const insertLine = db.prepare(
    'INSERT INTO lines (entry_id, account_id, amount_paise) VALUES (?, ?, ?)',
  );
  const accountId = db.prepare('SELECT id FROM accounts WHERE code = ?').pluck();
  const seen = db.prepare('SELECT 1 FROM entries WHERE source_ref = ?').pluck();
  const balanceOf = db
    .prepare(
      'SELECT COALESCE(SUM(amount_paise), 0) FROM lines JOIN accounts a ON a.id = account_id WHERE a.code = ?',
    )
    .pluck();
  const ruleFor = db.prepare(
    'SELECT account_code FROM memo_rules WHERE ? REGEXP pattern ORDER BY priority LIMIT 1',
  );

  // One balanced entry: its lines must sum to zero.
  const postEntry = db.transaction((entry) => {
    let sum = 0n;
    const { lastInsertRowid } = insertEntry.run(entry);
    for (const line of entry.lines) {
      const id = accountId.get(line.account);
      if (id === undefined) throw new Error(`unknown account ${line.account}`);
      insertLine.run(lastInsertRowid, id, line.paise);
      sum += line.paise;
    }
    if (sum !== 0n) throw new Error(`entry ${entry.sourceRef} does not balance (${sum})`);
    return lastInsertRowid;
  });

  // A bank statement is all or nothing: one bad line rolls back the file.
  const importStatement = db.transaction((bankAccount, rows) => {
    let posted = 0;
    for (const row of rows) {
      if (seen.get(row.ref)) continue;
      const rule = ruleFor.get(row.memo);
      const counter = rule ? rule.account_code : 'SUSPENSE';
      const paise = parsePaise(row.amount);
      postEntry({
        postedOn: row.date,
        memo: row.memo,
        sourceRef: row.ref,
        lines: [
          { account: bankAccount, paise },
          { account: counter, paise: -paise },
        ],
      });
      posted += 1;
    }
    return posted;
  });

  return {
    postEntry,
    importStatement,
    balance: (code) => balanceOf.get(code),
    *entriesSince(day) {
      yield* db.prepare('SELECT * FROM entries WHERE posted_on >= ? ORDER BY id').iterate(day);
    },
  };
}
