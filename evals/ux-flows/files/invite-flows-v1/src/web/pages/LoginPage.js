export function LoginPage({ error } = {}) {
  return `<main>
  <h1>Sign in to Crewbook</h1>
  ${error ? `<p role="alert">${error}</p>` : ''}
  <form method="post" action="/api/login">
    <label>Email <input name="email" type="email" required></label>
    <label>Password <input name="password" type="password" required></label>
    <button type="submit">Sign in</button>
  </form>
  <p><a href="/signup">Create a workspace</a></p>
</main>`;
}
