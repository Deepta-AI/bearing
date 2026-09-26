import { openDb, migrate } from '../db.js';
import { purgeOldClaims } from './claims.js';

const CLAIM_RETENTION_DAYS = 7;

export function sweep(db) {
  purgeOldClaims(db, CLAIM_RETENTION_DAYS);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const db = openDb(process.env.BILLING_DB ?? 'billing.db');
  migrate(db);
  sweep(db);
}
