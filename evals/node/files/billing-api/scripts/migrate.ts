// Applies pending migrations to BILLING_DB. Run by the release job only.
import { loadConfig } from '../src/config.ts';
import { applyMigrations, openDb } from '../src/db.ts';

const config = loadConfig(process.env);
const db = openDb(config.dbPath);
const applied = applyMigrations(db);
console.log(`migrate: ${applied.length} applied${applied.length ? ': ' + applied.join(', ') : ''}`);
db.close();
