import { bigint, index, pgTable, text, timestamp, uniqueIndex, jsonb, integer } from 'drizzle-orm/pg-core';

export const payments = pgTable(
  'payments',
  {
    id: text('id').primaryKey(),
    accountId: text('account_id').notNull(),
    amountMinor: bigint('amount_minor', { mode: 'number' }).notNull(),
    currency: text('currency').notNull(),
    status: text('status', { enum: ['authorized', 'captured', 'failed'] }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('payments_account_created').on(t.accountId, t.createdAt)],
);

export const idempotencyKeys = pgTable(
  'idempotency_keys',
  {
    accountId: text('account_id').notNull(),
    key: text('key').notNull(),
    statusCode: integer('status_code').notNull(),
    body: jsonb('body').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex('idempotency_keys_account_key').on(t.accountId, t.key)],
);
