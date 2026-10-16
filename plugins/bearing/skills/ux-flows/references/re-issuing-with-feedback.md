# ux-flows: re-issuing with feedback

Read when: `--feedback` is given, or the request asks for changes to an existing flow package; the first rule is in SKILL.md.

The previous version has readers: review notes, sign-offs and design
tickets cite its screen ids and its copy. The job is to change what the
feedback asks and to show every consequence, not to rewrite the package.

- Screens the feedback does not touch are carried across with their copy
  and states unchanged, even when the previous version used another
  layout. Where the template wants a row the old screen never had, write
  `n/a: not in v<n>, outside this feedback` and list the gap as a note;
  do not design it. Correcting a value that contradicts the code (step 2)
  is the exception, recorded in Changes.
- A removed screen keeps its inventory row with `removed in v<n+1>` in
  Status (the gate then skips it; it leaves the flowcharts and state
  tables), and its id is never reused. Everything it carried is moved or dropped on purpose,
  each named in Changes: disclosures and prices, approved or legal
  wording, its error states, its events, the stories it served.
- Re-read every review note, sign-off and ticket that cites the previous
  version. Each one the change touches is listed with what now needs
  re-approval or rescoping: approved wording that has to change for the
  new case (a sentence written for one item, now for twelve) goes back to
  whoever approved it, and a ticket that cites a removed id is named.
- Re-run step 2 against the change: new inputs (a list instead of one
  item) meet the same limits many times over. Recompute the numbers for
  the feedback's own example, and recheck numbers the previous version
  stated. When the feedback cites a real case (a customer, a ticket, a
  pasted list), walk that case through the new flow with its own records
  and dates, item by item: which entries are dropped, refused, sent or
  left waiting, and why.
