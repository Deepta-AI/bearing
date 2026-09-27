import { createHash } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { createApp } from '../src/app.ts';
import { applyMigrations, openDb, type Db } from '../src/db.ts';
import { createLogger } from '../src/log.ts';

export const KEY_A = 'test-key-acme';
export const KEY_B = 'test-key-globex';

const hash = (k: string) => createHash('sha256').update(k).digest('hex');

/** A migrated in-memory database with two accounts, their customers and invoices (copied from staging). */
export function seededDb(): Db {
  const db = openDb(':memory:');
  applyMigrations(db);
  db.exec(`
    INSERT INTO accounts (id, name) VALUES ('acc_a', 'Acme'), ('acc_b', 'Globex');
    INSERT INTO api_keys (key_hash, account_id) VALUES ('${hash(KEY_A)}', 'acc_a'), ('${hash(KEY_B)}', 'acc_b');
    INSERT INTO customers (id, account_id, name, email, created_at, deleted_at) VALUES
      ('cus_1', 'acc_a', 'First Customer', 'first@example.test', '2026-05-01T10:00:00.000Z', NULL),
      ('cus_2', 'acc_a', 'Second Customer', 'second@example.test', '2026-05-02T10:00:00.000Z', NULL),
      ('cus_3', 'acc_a', 'Gone Customer', 'gone@example.test', '2026-05-03T10:00:00.000Z', '2026-06-01T00:00:00.000Z'),
      ('cus_9', 'acc_b', 'Other Account Customer', 'other@example.test', '2026-05-01T09:00:00.000Z', NULL);
    INSERT INTO invoices (id, account_id, customer_id, number, status, amount_minor, currency, due_on, created_at) VALUES
      ('inv_01', 'acc_a', 'cus_1', 'A-0001', 'paid',  12500, 'EUR', '2026-06-01', '2026-05-05T08:00:00.000Z'),
      ('inv_02', 'acc_a', 'cus_1', 'A-0002', 'open',   4999, 'EUR', '2026-07-01', '2026-06-05T08:00:00.000Z'),
      ('inv_03', 'acc_a', 'cus_1', 'A-0003', 'draft',  7000, 'EUR', '2026-08-01', '2026-07-05T08:00:00.000Z'),
      ('inv_04', 'acc_a', 'cus_1', 'A-0004', 'void',   3000, 'EUR', '2026-07-15', '2026-06-05T08:00:00.000Z'),
      ('inv_05', 'acc_a', 'cus_2', 'A-0005', 'open',  99900, 'EUR', '2026-07-20', '2026-06-10T08:00:00.000Z'),
      ('inv_06', 'acc_a', 'cus_1', 'A-0006', 'paid',   2500, 'EUR', '2026-07-05', '2026-06-05 09:30:00'),
      ('inv_07', 'acc_a', 'cus_3', 'A-0007', 'open',   1500, 'EUR', '2026-06-20', '2026-05-20T08:00:00.000Z'),
      ('inv_08', 'acc_a', 'cus_1', 'A-0008', 'open',   1800, 'EUR', '2026-07-10', '2026-06-05 11:00:00 UTC'),
      ('inv_90', 'acc_b', 'cus_9', 'B-0001', 'open',   1000, 'USD', '2026-07-01', '2026-06-01T08:00:00.000Z');
  `);
  return db;
}

/** Calls the app in process, without a socket, and returns status, headers and parsed body. */
export async function inject(
  db: Db,
  opts: { method?: string; url: string; headers?: Record<string, string> },
): Promise<{ status: number; headers: Record<string, string>; body: any }> {
  const handler = createApp({ db, log: createLogger({}, () => {}) });
  const req = {
    method: opts.method ?? 'GET',
    url: opts.url,
    headers: opts.headers ?? {},
  } as unknown as IncomingMessage;
  let status = 0;
  let headers: Record<string, string> = {};
  let text = '';
  const res = {
    writeHead(s: number, h: Record<string, string>) {
      status = s;
      headers = h;
      return this;
    },
    end(chunk?: string) {
      text = chunk ?? '';
    },
  } as unknown as ServerResponse;
  await handler(req, res);
  return { status, headers, body: text ? JSON.parse(text) : undefined };
}
