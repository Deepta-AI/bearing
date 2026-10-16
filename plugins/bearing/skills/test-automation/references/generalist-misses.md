# test-automation: what a generalist misses

Read when the suite looks green: durability, side effects, races, validation probes, time, isolation, defaults.


- Durability: a read on the same database connection sees its own
  uncommitted write, so a test that writes and reads through one
  connection passes with the `commit()` deleted. Read back through a
  second connection or a fresh app on the same file.
- Side effect after commit: when the handler commits and then calls a
  webhook, a queue or a publisher, make that call fail in a test and
  assert what the client is told against what is stored. A 500 over a
  committed change invites a retry that applies it twice: a finding.
- Invariants over sums (refunds never exceed the total, stock never
  below zero) are check-then-act. A sequential test cannot catch the
  race; start N requests together behind a barrier (goroutines and a
  `sync.WaitGroup`, a thread pool), run with `-race` where the stack has
  it, and assert the invariant after. Code that reads, checks and writes
  under separate locks or transactions is a finding even when the
  sequential test passes.
- Validation probes beyond the row: zero, negative, the maximum, the
  empty string, a trailing newline (Python `re` `$` matches before a
  final `\n`; `fullmatch` or `\Z` does not), `true` where an int is
  expected (`bool` is an `int` in Python), a duplicate. A probe that
  exposes a defect is a strict expected failure plus a finding.
- Time: build instants in the zone the row states and let the clock
  seam convert (15:00 IST is 09:30 UTC); inject the clock, never sleep
  or read the wall clock. Test a window at its edge and one unit past.
- Isolation: no test opens the configured production path, database
  or URL. Point config at a temporary file and replace the outbound
  call with a double that records what was sent, or a local server.
- Defaults are findings: a secret with a guessable default
  (`changeme`) means an unset variable leaves the endpoint open; say
  that consequence, not only the default.
