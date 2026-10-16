# branch-review: reading past the diff

Read when step 4 is done with the engine and you read the lines the change did not touch.

Then read past the diff yourself; the engine and the agents mostly
read what changed, and the costliest bugs of a change sit in lines it
did not touch. For every table, column, function, setting and
external call the change adds or alters:
- who else reads or writes it (Grep the name across the repository,
  including scripts, cron, reports and jobs), and whether each one
  is still right with the change in place;
- whether the repository already models the concept the change
  introduces (an existing column, helper, status or doc rule) that
  the change bypasses or leaves stale;
- the invariant a reader would state in one sentence ("stock never
  goes below zero", "a coupon is redeemed once") and the sequence of
  normal calls, not only one call, that breaks it;
- the states the operation is allowed from, and what happens on each
  failure after a side effect (commit, external call, message);
- defaults and absent inputs: a missing header, env var or field that
  makes a check fail open;
- windows, TTLs, retries and limits compared across components and
  documents, with the numbers computed from the code (a constant's
  name and comment are not its value; `15 * 60 * 1000` in a field read
  as seconds is 10 days);
- messages and callbacks that arrive twice, together, late or out of
  order, where the code assumes once and in order.
A finding from this pass goes to step 5 like any other.
