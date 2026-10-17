# tracker-sync: update and trace, items 3 to 7

Read when you run update, trace or mark a ticket done.

3. **Commits.** `git log --format='%h %s' origin/<base>..HEAD`. Attach the
   ones whose subject carries this key. One carrying another key belongs
   to that ticket: note it, change nothing on it. List keyless ones for
   the user to place.
4. **Test cases: promised against delivered.** Take the ids the test case
   file assigns to this key. For each, a test must name it, run and pass.
   Run the suite (`make check` or the repository's command) and read its
   summary: a `todo`, `skip` or commented-out test is not coverage, and a
   commit subject claiming an id is not evidence. Report covered, missing
   and placeholder ids with counts ("2 of 3 covered; TC-104 is a todo").
5. **Behaviour against the decision.** For each ADR the branch adds or
   cites, quote its `Status:` line (Proposed is not Accepted) and check
   the code does what its Decision section says. A gap here or in step 4
   means the ticket is not complete against its own test cases; say so
   plainly, whatever status is proposed.
6. **MR link.** From `--mr` or the user. The remote gives the host and
   project (`git remote -v`), never the MR number: without the link, ask
   for it and leave the field empty, or give the branch URL on the
   remote's host. Never guess a number.
7. Run `brg-tracker update` and `brg-tracker trace` with those facts or,
   with no tracker, print them as exact commands (Step 4). Called from
   `merge-request`, exit 3 means "tracker: none", reported, not a failure.
   Status names match case-insensitively against what the tracker offers;
   an unknown name stops with the adapter's list.
