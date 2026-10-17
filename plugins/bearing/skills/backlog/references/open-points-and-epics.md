# backlog: open points and story ids

Read when: steps 3 and 4: the question register columns and the id scheme.

3. Open points. Every ambiguity, gap or contradiction met while judging,
and every decision the PRD leaves open that a story had to take (a
limit, a timing, a routing rule, what happens at the edge), becomes a
`Q-nnn` row in `docs/product/questions.md` (or in the existing
backlog's own question table, continuing its numbering): Kind
(open-question, gap, contradiction), Where, Basis (stated, inferred,
convention, assumption), the readings available, the Decision taken
so the work is not blocked, Why, Affects and Status. Open assumptions
come first and are listed under "Needs your confirmation". Replace
every Affects cell, including `prd`'s REQ ids, with the story ids
the decision changes; it is never empty.
4. Group stories into epics `EP-nn` by user goal, never by layer ("API",
"database" are not epics). New backlog: assign the persona group from
the PRD's personas (00 end users, 01 admins, 02 operators, 03
integrations) and the story id is `US-<group>-<nnn>`, sequential within
the group, chosen by who triggers the behaviour. Existing backlog: a
new story takes the backlog's own scheme, the next number after the
highest ever used (withdrawn ids count, never reused); no second id
scheme is added beside it.
