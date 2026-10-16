# backlog: stories, tasks, flows and import

Read when: steps 5, 6, 8 and 10: what each file contains.

5. New backlog: write `docs/product/backlog.md` from `templates/story.md`
(an existing one is edited in its own shape, below): the story
index, then per story: narrative; "Why it matters" citing a `B` id and
how the story moves it; "From the PRD" quoting every covered REQ in the
PRD's words; preconditions; at most seven acceptance criteria in
Given/When/Then with ids `AC-US-nn-nnn-k` and a `Covers: REQ-nnn` line
each; "Not in this story", each exclusion naming where it lives;
"Depends on" with the reason; assumptions citing their Q-nnn; Points
(`TBD` until `estimate`); priority (Must, Should, Could). Every REQ
the story covers appears in at least one AC.
6. Full pack only (see Scope). Write `docs/product/tasks.md` from `templates/tasks.md`: per story the
development tasks `US-nn-nnn-D1` upward and the test tasks
`US-nn-nnn-T1` upward, each with discipline (backend, frontend, mobile,
qa, devops, or design and content for deliverables that are not code;
a test task is qa), Estimate (hours from `estimate`,
else `TBD`), Depends on, Done when and the AC ids it verifies. Every
story gets both kinds and every AC is verified by a test task. A task
over 8 hours is two tasks.

8. Full pack only. Write `docs/product/user-flows.md` from `templates/user-flows.md`: at
least one journey per epic with persona, platforms, trigger, what holds
before it starts, the step table (Screen, The user, The system, Story),
alternate paths, failures with the story that handles each, and the end
state. A failure no story handles is a `gap:` for the user.

10. Full pack only. Write `docs/product/IMPORT.md` from `templates/import.md`: the files
and how each imports (`tracker-sync sync` for epics and stories, CSV
for tasks), the open assumptions to confirm before committing, what is
still open, and what is out of scope. Print the gate's lines unchanged.
Never write a count the script did not print.
