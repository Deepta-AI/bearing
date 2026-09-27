import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createStore } from '../src/server/store.js';
import { signup, login } from '../src/server/auth.js';

test('login returns the user and their workspace', () => {
  const store = createStore();
  const { workspace } = signup(store, { email: 'Owner@acme.test', password: 'long-enough-pw', workspaceName: 'Acme' });
  const out = login(store, { email: 'owner@acme.test ', password: 'long-enough-pw' });
  assert.equal(out.workspace.id, workspace.id);
  assert.throws(() => login(store, { email: 'owner@acme.test', password: 'wrong' }), { code: 'BAD_LOGIN' });
});
