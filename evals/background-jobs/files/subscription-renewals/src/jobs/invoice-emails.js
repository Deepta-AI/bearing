import { claim, markDone, release } from './claims.js';

// Sends the invoice email for every charge not yet emailed.
export async function sendInvoiceEmails(db, mailer) {
  const pending = db.prepare('SELECT * FROM charges WHERE emailed_at IS NULL').all();
  let sent = 0;
  for (const ch of pending) {
    const key = `invoice-email:${ch.id}`;
    if (!claim(db, key)) continue;
    try {
      await mailer.sendInvoice(ch);
    } catch (err) {
      release(db, key);
      throw err;
    }
    db.exec('BEGIN');
    db.prepare('UPDATE charges SET emailed_at = CURRENT_TIMESTAMP WHERE id = ?').run(ch.id);
    markDone(db, key);
    db.exec('COMMIT');
    sent += 1;
  }
  return sent;
}
