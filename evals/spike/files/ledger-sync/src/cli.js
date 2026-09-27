#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { open } from './db.js';
import { ledger } from './ledger.js';
import { backup } from './backup.js';
import { parseStatement } from './statement.js';
import { formatPaise } from './amounts.js';

const [cmd, dbPath, arg] = process.argv.slice(2);
if (!cmd || !dbPath) {
  console.error('usage: ledger-sync sync|balance|backup <db> <inbox|account|dir>');
  process.exit(2);
}
const db = open(dbPath);
const l = ledger(db);

if (cmd === 'sync') {
  for (const name of fs.readdirSync(arg).filter((n) => n.endsWith('.csv')).sort()) {
    const bank = name.split('-')[0].toUpperCase();
    const n = l.importStatement(bank, parseStatement(fs.readFileSync(path.join(arg, name), 'utf8')));
    console.log(`${name}: ${n} entries posted`);
  }
} else if (cmd === 'balance') {
  console.log(formatPaise(l.balance(arg)));
} else if (cmd === 'backup') {
  console.log(await backup(db, arg));
} else {
  console.error(`unknown command ${cmd}`);
  process.exit(2);
}
db.close();
