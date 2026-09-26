// Claims make a job's effect happen once. claim() inserts the key; the
// primary key on job_claims means only one caller can win.

export function claim(db, key) {
  try {
    db.prepare("INSERT INTO job_claims (key, state) VALUES (?, 'in_progress')").run(key);
    return true;
  } catch (err) {
    if (String(err.message).includes('UNIQUE constraint failed')) return false;
    throw err;
  }
}

export function markDone(db, key) {
  db.prepare("UPDATE job_claims SET state = 'done', done_at = CURRENT_TIMESTAMP WHERE key = ?").run(key);
}

export function release(db, key) {
  db.prepare("DELETE FROM job_claims WHERE key = ? AND state = 'in_progress'").run(key);
}

// Keeps the table small; called nightly by sweep.js.
export function purgeOldClaims(db, days) {
  db.prepare("DELETE FROM job_claims WHERE claimed_at < datetime('now', ?)").run(`-${days} days`);
}
