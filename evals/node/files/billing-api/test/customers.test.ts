import assert from 'node:assert/strict';
import { test } from 'node:test';
import { KEY_A, KEY_B, inject, seededDb } from './helpers.ts';

test('lists the account customers newest first, without deleted ones', async () => {
  const res = await inject(seededDb(), { url: '/customers', headers: { 'x-api-key': KEY_A } });
  assert.equal(res.status, 200);
  assert.deepEqual(
    res.body.items.map((c: { id: string }) => c.id),
    ['cus_2', 'cus_1'],
  );
  assert.equal(res.body.nextCursor, null);
});

test('pages with a cursor', async () => {
  const db = seededDb();
  const first = await inject(db, { url: '/customers?limit=1', headers: { 'x-api-key': KEY_A } });
  assert.equal(first.body.items[0].id, 'cus_2');
  assert.ok(first.body.nextCursor);
  const second = await inject(db, {
    url: `/customers?limit=1&cursor=${first.body.nextCursor}`,
    headers: { 'x-api-key': KEY_A },
  });
  assert.deepEqual(
    second.body.items.map((c: { id: string }) => c.id),
    ['cus_1'],
  );
});

test('rejects a limit above 100', async () => {
  const res = await inject(seededDb(), { url: '/customers?limit=101', headers: { 'x-api-key': KEY_A } });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'validation_error');
});

test('another account customer is not found', async () => {
  const res = await inject(seededDb(), { url: '/customers/cus_1', headers: { 'x-api-key': KEY_B } });
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'not_found');
});

test('requires an api key and echoes the request id', async () => {
  const res = await inject(seededDb(), { url: '/customers', headers: { 'x-request-id': 'req-123' } });
  assert.equal(res.status, 401);
  assert.equal(res.headers['x-request-id'], 'req-123');
  assert.equal(res.body.error.requestId, 'req-123');
});
