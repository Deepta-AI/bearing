# high-level-design: traps

Read before step 9: what separates a design that survives review from one that reads well.

What separates a design that survives review from one that reads well.
Check each against the draft before step 9; each one that applies gets a
sentence in the section named, with the repository's numbers. The critic
in step 9 is given this list and checks the draft against it too.

- **Peaks (scaling).** Size for the worst window, not the average or the
  first burst you find. Overlay every family of due times (each offset
  from each cluster of start times: a 24 hour reminder for tomorrow's
  09:00 lands with today's 2 hour reminders for 11:00) and the shared
  limit's other traffic at that same hour. Compute the count, divide by
  the net rate, compare with the requirement.
- **Check then act (failure modes).** A condition that guards a side
  effect (status, opt-out, a switch, a version) is read at the moment of
  the side effect, or the state change and the queued work change in one
  transaction. A check at enqueue or claim time leaves a window as long
  as the queue ahead of it; state the window or close it. A message
  payload is a snapshot, not the truth; re-read the row.
- **Side effect then record (failure modes).** For every external call
  followed by a local write (send then mark done, publish then commit
  the offset), a crash between them gives a duplicate or a loss. Say
  which the design accepts, make the retry policy agree, and name the
  provider's idempotency key, looked up in its documentation (see
  Provider facts); a retry without one sends the side effect twice.
- **Two systems, one change (data).** A database write plus a publish or
  a call is not atomic. Use an outbox read by a relay that retries, or
  state which orphan or loss results.
- **Parallelism (scaling).** More workers over a table need a claim (row
  lock with skip, or a status change before work); more consumers over
  a per-process limiter multiply the rate.
- **Retries are bounded by usefulness (failure modes).** Every retry
  has a deadline after which the work is dropped (a reminder after the
  appointment is noise). A retry that blocks an ordered partition or
  queue holds up everything behind it; say where retries wait.
- **Late arrivals (flows).** Work created after its due time (a booking
  inside the reminder window) is sent at once, skipped, or partly sent;
  pick one.
- **Controls (rollout).** A pilot list, kill switch or transport flag
  is operator owned and separate from any setting users own. Reusing a
  user's switch (a clinic's own on/off) for a pilot overwrites their
  choice and cannot be told apart from it later; check every default.
- **Growth (data).** Each new row stream gets a rows-a-day number and a
  retention rule, especially rows in a table something polls.
- **The numbers agree with each other.** Batch sizes, lease or stale
  claim timeouts, poll intervals and retry deadlines are checked against
  the rate the design states (a lease shorter than the time to send the
  batch it claims resends or drops the tail).
- **Authority the code lacks (security).** A requirement that names a
  role (an admin, an owner) needs an auth model; if the routes are open
  today, say so and list it as needed, never as existing.
- **Repeated requests (interfaces).** A client repeats writes: a double
  tap, the back button, a network retry. Every write endpoint takes a
  request id the client makes once, stored under a unique constraint, and
  a repeat returns the first result with no second row and no second side
  effect. A form-only guard (a disabled button) does not cover retries.
- **Untrusted content (security).** Text the system shows but did not
  write (social posts, reviews, names from forms, anything fetched) is
  rendered as text, never as markup, and its media comes only from named
  hosts. Staff or admin sessions live on a separate origin from pages that
  show such content, so a script that slips onto a public page cannot use
  a staff session.
- **Model output on a public path (security).** An LLM answer shown to
  people who are not staff is grounded (the model sees only retrieved
  passages), checked (an answer stating a number, price, date or claim its
  sources lack is replaced by a fallback), bounded (input length, spend
  cap) and evaluated before release, injection attempts included; route
  the design through `llm-guardrails` and `llm-eval` and name both here.
- **Provider facts (external integrations).** A provider's rate limits,
  quotas, idempotency support, regions and retention come from its
  documentation, cited with a link in the section that uses them; the
  scaling arithmetic uses the documented number. "assumption:" is only for
  what the documentation does not say, and each one is an open question
  with an owner.
