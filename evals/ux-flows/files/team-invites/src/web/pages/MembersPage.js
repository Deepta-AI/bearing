// Settings > Members. Lists the workspace's members. Invite controls are
// CRW-88 (flows first); the API for them exists in src/server/invites.js.
export function MembersPage({ viewer, members = [] }) {
  const isAdmin = viewer.role === 'admin';
  const rows = members
    .map(
      (m) => `<tr><td>${m.email}</td><td>${m.role}</td>` +
        (isAdmin && m.userId !== viewer.userId ? `<td><button data-remove="${m.userId}">Remove</button></td>` : '<td></td>') +
        '</tr>',
    )
    .join('');
  return `<main>
  <h1>Members</h1>
  <table><thead><tr><th>Email</th><th>Role</th><th></th></tr></thead><tbody>${rows}</tbody></table>
</main>`;
}
