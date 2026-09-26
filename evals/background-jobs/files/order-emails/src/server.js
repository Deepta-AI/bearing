import http from 'node:http';
import { openDb, migrate } from './db.js';
import { Mailer } from './mailer.js';
import { placeOrder } from './checkout.js';

const db = openDb(process.env.SHOP_DB ?? 'shop.db');
migrate(db);
const relay = { async send() { throw new Error('configure SMTP_RELAY_URL'); } };
const mailer = new Mailer(relay);

http
  .createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== '/orders') {
      res.writeHead(404).end('not found');
      return;
    }
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const { email, items } = JSON.parse(raw || '{}');
    const orderId = await placeOrder(db, mailer, email, items);
    res.writeHead(201, { 'Content-Type': 'application/json' }).end(JSON.stringify({ orderId }));
  })
  .listen(8000);
