import { migrate } from 'drizzle-orm/node-postgres/migrator';
import pg from 'pg';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDb } from './db/client.js';

const config = loadConfig(process.env);
const pool = new pg.Pool({ connectionString: config.DATABASE_URL, max: 10 });
const db = createDb(pool);
// Apply pending migrations so a fresh environment comes up with the refunds table.
await migrate(db, { migrationsFolder: 'drizzle' });
const app = buildApp({ db, logLevel: config.LOG_LEVEL, ledgerUrl: config.LEDGER_URL });
app.addHook('onClose', async () => {
  await pool.end();
});

await app.listen({ port: config.PORT, host: '0.0.0.0' });

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.once(signal, () => {
    const timer = setTimeout(() => process.exit(1), config.SHUTDOWN_TIMEOUT_MS);
    timer.unref();
    app.close().then(
      () => process.exit(0),
      () => process.exit(1),
    );
  });
}
