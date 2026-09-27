// Sign-up creates a new workspace with the caller as its admin
// (src/server/auth.js signup). There is no way to join an existing one here.
export function SignupPage({ error } = {}) {
  return `<main>
  <h1>Create your workspace</h1>
  ${error ? `<p role="alert">${error}</p>` : ''}
  <form method="post" action="/api/signup">
    <label>Work email <input name="email" type="email" required></label>
    <label>Password <input name="password" type="password" minlength="10" required></label>
    <label>Workspace name <input name="workspaceName" required></label>
    <button type="submit">Create workspace</button>
  </form>
  <p><a href="/login">I already have an account</a></p>
</main>`;
}
