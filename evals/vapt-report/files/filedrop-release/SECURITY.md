# Security checklist

Every release is checked against this list before it is deployed.

1. Every file read, download and preview is scoped to the caller's tenant.
2. Session cookies are signed with a secret from the secret store; the
   service refuses to start without one.
3. No credentials or API keys in the repository or in ConfigMaps; they come
   from Kubernetes Secrets.
4. Share links are unguessable and expire.
5. Uploaded content is never rendered inline (Content-Disposition:
   attachment, X-Content-Type-Options: nosniff).
6. Errors returned to clients carry no internal paths or stack traces.
7. Passwords are stored with a slow, salted hash.
