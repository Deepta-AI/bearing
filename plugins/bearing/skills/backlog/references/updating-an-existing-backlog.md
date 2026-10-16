# backlog: updating an existing backlog

Read when: the backlog already exists and is being tracked.

A backlog people are tracking is edited, not rebuilt. Find what changed
and touch only the stories a change lands on.

- Diff the statements themselves, not the change log. Compare each REQ's
  current wording with the criteria that cover it (and the previous PRD
  in git history when there is one). Change logs omit edits, and the
  omitted ones are small: a boundary made inclusive, "days" becoming
  "working days", "each" becoming "any", a unit. A boundary change against a Done story is new work like
  any other.
- A new statement changes existing stories it never names. For each
  one, ask who acts, who is notified, who may decide and when, and check
  those against every Done and In progress story and the code behind
  them: a new actor who must approve breaks a shipped "only the owner
  may approve" check, and a new recipient changes a notification story
  under way. Name each such story and
  the code rule it breaks.
- Where a new statement overlaps an existing story, state the difference
  in one line (who acts, on what trigger, for how long) or merge them.

- Shape: keep the file's headings, id scheme, AC numbering, status column
  and question table. New stories are written in that same shape. Stories
  no change touches keep their text; do not upgrade them to the house
  template.
- Each changed statement, by the status of the story it lands on:
  - To do: edit the story in place and say so in the report.
  - In progress: do not change the scope mid-sprint silently. Leave the
 criteria, add a note naming the change, and raise a Q-nnn with the
 readings (finish as planned and follow up, change it in this sprint,
 stop it).
  - Done: never rewrite a shipped criterion as if the new value had been
 delivered. Add a new story that changes it, citing the Done story, and
 name the code, config and tests that still hold the old value.
- A withdrawn statement: a To do story is marked `withdrawn:` in place
  with the reason. An In progress story keeps its status: someone is
  building it and the tracker mirrors it, so withdrawal is proposed in a
  Q-nnn with the readings and the team changes the status. Search code and tests for the
  story id (the gate lists them): each hit is work someone must keep,
  repoint or remove, so it goes in that Q-nnn. Never edit code or tests
  from this skill.
- A new statement that restates an existing capability is folded into that
  story (its Covers line), not given a story of its own.
- A new statement that conflicts with an accepted ADR or the PRD's own
  non-goals is not written as ready work: the story is blocked on its
  Q-nnn, whatever reading you assume.
- New stories are not placed in the running sprint; propose, do not
  schedule.
- The report lists the stories added, changed, reopened and withdrawn, and
  copies the gate's `ids:` line, whose "changed since HEAD" list must
  match that summary.
