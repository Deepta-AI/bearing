import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sendInvoiceEmails } from '../src/jobs/invoice-emails.js';
import { seededDb } from './helpers.js';

test('each charge is emailed once even when the job runs twice', async () => {
  const db = seededDb();
  db.prepare("INSERT INTO charges (subscription_id, period, amount_paise, provider_ref) VALUES ('sub_1', '2026-10', 149900, 'ch_1')").run();
  const sent = [];
  const mailer = { async sendInvoice(ch) { sent.push(ch.id); } };
  await Promise.all([sendInvoiceEmails(db, mailer), sendInvoiceEmails(db, mailer)]);
  assert.equal(sent.length, 1);
});
