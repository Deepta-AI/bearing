# react-native: traps in reading the repository and in writes

Read when docs disagree, a schema covers a server-owned value, or the task adds a submit or a POST.

- Docs disagree. The API reference and its changelog beat a README line;
  an Accepted ADR beats both. Read the changelog to its newest entry: a
  status, field or limit added there and missing from the body is still
  live. Say which document you followed and correct or flag the stale one.
- A `z.enum` over a server-owned value (status, type) turns one new value
  into a failed page for that customer. Accept every value the docs and
  changelog name, and render an unknown one as a neutral label
  (`.catch()`, or `z.string()` with a known-label map), never a throw.

- A POST that creates something carries an idempotency key generated once
  per user intent (when the form opens or on first submit), kept across
  retries, and replaced only after success. A key made per request does
  not stop the duplicate a timeout-then-retry creates.
- Required choices are required: never default a missing reason or
  selection to a value the customer did not pick.
- Show an action only when the server will accept it (a return window, a
  status): compute it from the data, and map the refusal (422) to copy.
