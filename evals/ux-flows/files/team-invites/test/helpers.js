import { createStore } from '../src/server/store.js';
import { signup } from '../src/server/auth.js';

export function seeded({ plan = 'starter', allowedDomains = [] } = {}) {
  const store = createStore();
  const { user, workspace } = signup(store, { email: 'owner@acme.test', password: 'long-enough-pw', workspaceName: 'Acme' });
  workspace.plan = plan;
  workspace.allowedDomains = allowedDomains;
  return { store, admin: user, ws: workspace };
}
