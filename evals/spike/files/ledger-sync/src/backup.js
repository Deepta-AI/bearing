import path from 'node:path';

// Online backup while the nightly sync may still be writing.
export async function backup(db, dir, now = new Date()) {
  const file = path.join(dir, `ledger-${now.toISOString().slice(0, 10)}.db`);
  await db.backup(file);
  return file;
}
