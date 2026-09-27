import pg from 'pg';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDb } from './db/client.js';

const config = loadConfig(process.env);
const pool = new pg.Pool({ connectionString: config.DATABASE_URL, max: 10 });
const app = buildApp({ db: createDb(pool), logLevel: config.LOG_LEVEL });
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
