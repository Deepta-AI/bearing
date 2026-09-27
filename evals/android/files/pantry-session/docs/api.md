# Backend contract (the parts the app uses)

Base URL: `API_BASE_URL` (production `https://api.pantry.example.com/`).

## Auth

- `POST auth/login` `{email, password}` returns
  `{access_token, refresh_token, expires_in, user_id}`. `expires_in` is in
  seconds and is 900 (the access token lives 15 minutes).
- `POST auth/refresh` `{refresh_token}` returns the same shape. Refresh
  tokens live 30 days and ROTATE: each refresh returns a new refresh token
  and the one sent is revoked at once. Sending a revoked refresh token
  revokes the whole session family (the user must sign in again).
  A refresh token that is expired, revoked or already used is refused
  with `400 {"error": "invalid_grant"}`; that is the only answer that
  means the session is over. Under load the endpoint answers `429` with
  `Retry-After`, and during deploys `503`; retry those later.
- `POST auth/logout` with the bearer token revokes the refresh token.
- Any authenticated call with an expired access token returns 401.

## Orders

- `GET orders` returns the signed-in user's orders, newest first. Order ids
  are positive integers.
