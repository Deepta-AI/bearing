import { TENANTS_BY_HOST, THEMES } from './registry.js';

// The only roles a tenant may set (ADR 0004).
export const ALLOWED_ROLES = [
  'accent',
  'accent-hover',
  'accent-active',
  'on-accent',
  'accent-subtle',
  'focus',
  'link',
];

// Self-hosted display faces a tenant may pick (src/styles/fonts.css).
export const DISPLAY_FACES = ['Inter', 'Fraunces'];

const COLOUR = /^(#[0-9a-fA-F]{6}|oklch\(\s*[0-9.]+%?\s+[0-9.]+\s+[0-9.]+\s*\))$/;

export function isColour(v) {
  return typeof v === 'string' && COLOUR.test(v);
}

function block(selector, roles) {
  const lines = ALLOWED_ROLES.filter((r) => isColour(roles?.[r])).map(
    (r) => `  --color-${r}: ${roles[r]};`,
  );
  return `${selector} {\n${lines.join('\n')}\n}`;
}

export function tenantCss(theme) {
  const sel = `:root[data-tenant="${theme.name}"]`;
  return [block(sel, theme.light), block(`${sel}[data-theme="dark"]`, theme.dark)].join('\n');
}

export function resolveTenant(host) {
  const name = TENANTS_BY_HOST[host];
  return name ? THEMES[name] : null;
}

export function applyTenant(host, doc) {
  const theme = resolveTenant(host);
  if (!theme) return { name: null, displayName: 'Patient portal', logo: null };
  const style = doc.createElement('style');
  style.id = 'tenant-theme';
  style.textContent = tenantCss(theme);
  doc.head.appendChild(style);
  doc.documentElement.dataset.tenant = theme.name;
  if (DISPLAY_FACES.includes(theme.display)) {
    doc.documentElement.style.setProperty('--font-display', `'${theme.display}', system-ui, sans-serif`);
  }
  return { name: theme.name, displayName: theme.displayName, logo: theme.logo };
}
