// Maps a path to a page. `shell` is the chrome it renders in.
export function route(path) {
  let m;
  if (path === '/app/invoices') return { screen: 'invoices', shell: 'app', params: {} };
  if ((m = /^\/app\/invoices\/(\w+)\/preview$/.exec(path))) {
    return { screen: 'invoice_preview', shell: 'app', params: { id: m[1] } };
  }
  if (path === '/app/settings') return { screen: 'settings', shell: 'app', params: {} };
  if ((m = /^\/pay\/([0-9a-f]+)$/.exec(path))) return { screen: 'pay', shell: 'pay', params: { token: m[1] } };
  return null;
}
