# prd: inference, conflict and what is not a requirement

Read when you mark inference or conflict, check statements against the ADRs and code, or judge whether a doubt is a requirement, a question or a delivery matter (step 6).

6. Mark inference and conflict. Anything you add to complete a section
   that the input does not state is prefixed `inferred:`; two passages
   that disagree are a contradiction; a capability the input needs but
   never states is a gap. Each is one `Q-nnn` entry. Never add a
   requirement statement this way; a missing capability is a question,
   not a REQ. Then check every statement against the repository, not only
   against the input: read each ADR and grep the code for the statement's
   nouns (events, fields, stored data). A statement an accepted ADR
   forbids (a new personal data field, a payment, a store the ADR puts
   elsewhere), or that needs data or events the code shows the system
   does not receive, is a contradiction naming the ADR or file and line;
   the statement is flagged `blocked: Q-nnn`, not written as buildable,
   and the ADR is never edited or superseded on the client's behalf.
   Behaviour the team would add for a sound build (idempotent event
   handling, what happens when a service is down, uniqueness rules,
   browser support, backups, rate limits) is not a requirement: it is
   left to design, never a register entry and never a REQ in the
   client's voice. So is a choice between technologies the input names
   as alternatives. Who builds, supplies, translates, hosts, pays for,
   owns, staffs or signs off anything, and the launch date and budget,
   are delivery questions: they never enter the PRD or the register. A
   legal duty the input names is a constraint; the skill does not add
   legal analysis or question the client's registrations. Details the input leaves out of a new
   capability (amounts, limits, validity, refund rules) stay open
   questions; do not choose them. Numbers the input derives (a reward
   every Nth visit from an average bill) are recomputed, and any
   alternative offered to the client is recomputed too.
