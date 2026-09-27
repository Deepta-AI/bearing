import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MembersPage } from '../src/web/pages/MembersPage.js';
import { SignupPage } from '../src/web/pages/SignupPage.js';

test('members page hides remove from members', () => {
  const members = [{ userId: 'u1', email: 'a@acme.test', role: 'admin' }, { userId: 'u2', email: 'b@acme.test', role: 'member' }];
  assert.match(MembersPage({ viewer: { userId: 'u1', role: 'admin' }, members }), /data-remove="u2"/);
  assert.doesNotMatch(MembersPage({ viewer: { userId: 'u2', role: 'member' }, members }), /data-remove/);
});

test('sign-up creates a workspace', () => {
  assert.match(SignupPage(), /Create your workspace/);
});
