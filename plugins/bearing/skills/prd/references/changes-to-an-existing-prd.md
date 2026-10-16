# prd: changes to an existing PRD

Read when the input changes, withdraws or reverses a statement or a decision of an existing PRD (step 7a).

7a. Changes to an existing PRD (a client email after a demo, a change
   request). For each statement the input touches:
   - Dropped for now: keep the id and text, flag `withdrawn:` with the
     date and the passage; say whether it is deferred (the client says it
     comes back) or removed.
   - Meaning changed (a different rule, amount, trigger or scope): stories
     and tests already cite the id, so the id never takes the new meaning.
     Flag the old one `withdrawn: replaced by REQ-nnn` and write the new
     rule as a new id citing the passage. Only a wording fix that changes
     no test may be amended in place, with a dated note.
   - A decision the client confirmed earlier and now reverses: the
     confirmed entry is not rewritten. Add a dated line to it ("reversed
     by the client on <date>, see Q-nnn or REQ-nnn") and record the new
     answer with its source; the history must show both answers.
   - An answer to an open entry: record it with the date and passage and
     set the entry `confirmed`; when the input asserts the PRD already
     says something it does not (a limit the PRD only assumed), say so in
     the entry rather than treating it as existing.
   - New statements are checked under step 6 exactly like a first brief.
   Then list every story that carries a withdrawn, replaced or blocked id,
   with its status from the stories file (in progress stories first), and
   the code or tests that cite the id (grep for it). Never edit stories,
   tests or code from this skill; name them for the user.
