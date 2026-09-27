import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { ALLOWED_ROLES, DISPLAY_FACES, isColour, tenantCss, resolveTenant } from '../src/theme/applyTenant.js';
import { THEMES, TENANTS_BY_HOST } from '../src/theme/registry.js';

test('every registered host points at a known theme', () => {
  const hosts = Object.keys(TENANTS_BY_HOST);
  assert.ok(hosts.length > 0, 'no tenants registered');
  for (const h of hosts) assert.ok(THEMES[TENANTS_BY_HOST[h]], `${h} has no theme`);
});

test('every theme sets every allowed role in both modes with a colour', () => {
  const names = Object.keys(THEMES);
  assert.ok(names.length > 0, 'no themes');
  for (const name of names) {
    const t = THEMES[name];
    assert.equal(t.name, name);
    for (const mode of ['light', 'dark']) {
      for (const role of ALLOWED_ROLES) {
        assert.ok(isColour(t[mode]?.[role]), `${name}.${mode}.${role} is not a colour`);
      }
    }
  }
});

test('logo is null or a self-hosted file under the tenant folder', () => {
  for (const t of Object.values(THEMES)) {
    if (t.logo === null) continue;
    assert.match(t.logo, new RegExp(`^/assets/tenants/${t.name}/`));
    assert.ok(existsSync(new URL(`../public${t.logo}`, import.meta.url)), `${t.logo} missing`);
  }
});

test('display face is self-hosted', () => {
  for (const t of Object.values(THEMES)) {
    if (t.display) assert.ok(DISPLAY_FACES.includes(t.display), `${t.name}: ${t.display}`);
  }
});

test('tenantCss applies only allowed roles with colour values', () => {
  const css = tenantCss({
    name: 'x',
    light: { accent: '#112233', radius: '0', 'on-accent': 'red; } body { display: none' },
    dark: { accent: '#445566' },
  });
  assert.match(css, /--color-accent: #112233;/);
  assert.doesNotMatch(css, /radius|display: none/);
});

test('harbor resolves from its host', () => {
  assert.equal(resolveTenant('portal.harborhealth.example').name, 'harbor');
  assert.equal(resolveTenant('unknown.example'), null);
});
