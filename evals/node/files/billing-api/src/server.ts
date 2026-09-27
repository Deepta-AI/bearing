import { createServer } from 'node:http';
import { createApp } from './app.ts';
import { loadConfig } from './config.ts';
import { openDb } from './db.ts';
import { createLogger } from './log.ts';

const config = loadConfig(process.env);
const log = createLogger({ service: 'billing-api' });
const db = openDb(config.dbPath);
const server = createServer({ requestTimeout: 15_000 }, createApp({ db, log }));

server.listen(config.port, () => log.info('listening', { port: config.port }));

function shutdown(signal: string) {
  log.info('shutting down', { signal });
  const timer = setTimeout(() => process.exit(1), config.shutdownTimeoutMs);
  timer.unref();
  server.close(() => {
    db.close();
    process.exit(0);
  });
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
