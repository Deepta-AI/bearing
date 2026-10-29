# prd: resolving the register with the user

Read when you reach step 10 and ask the open entries round by round.

10. Resolve the register in this session; nothing is sent outside it. Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/prd/scripts/register_answers.py" rank`
   for the open entries, ranked: open assumptions first, then by
   how many statements each affects, so the first round settles what
   blocks the most. Print the count and ask the first round at once with
   AskUserQuestion, the three highest-impact entries; a question about how to
   go through them comes after a round, never before the first, so the
   register is not skipped by a reader who missed it in a long reply. After
   each round offer the next three, only the assumptions, or stop (the default
   if unanswered). Up to three entries a call, each a question in
   plain words (the register's text is for engineers): the assumed
   reading first, labelled "(Assumed)", then the other readings, at most
   four options (the user can always type their own); put the
   experiment in an option's description when the entry has one, and
   group entries on one topic in the same round. Where AskUserQuestion
   is not available, ask the same round as a numbered list and accept
   short answers ("Q-005 c, Q-021 keep, Q-006 ask"). A user who cannot
   answer yet says so: record it as `ask-client` with who will be asked.
   Write the answers to
   `.bearing/answers-<date>.json` and apply them with
   `register_answers.py apply --answers <file> --source "<who> in session"`,
   which confirms entries with date and source, keeps the old
   decision as history and rewrites the confirmation list and counts.
   An `other` answer stays open: judge it under step 7a (a changed rule
   is a new REQ, never an edit), then set the entry. Finally update the
   counts in section 7 of the PRD and print what was confirmed, what
   needs review and what waits on the client.
