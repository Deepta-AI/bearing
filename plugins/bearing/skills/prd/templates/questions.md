# Open questions: <product>

<!-- Template guidance: docs/product/questions.md, the register of every
     point the input left open and the decision taken so work is not
     blocked. prd writes it with the PRD; backlog adds the points it
     meets while writing stories and replaces each Affects cell with the
     story ids. The client reads "Needs your confirmation" first; the
     coverage gate parses the register table, so keep its header row and
     column names, and a table-to-CSV exporter reads that one table. Every
     comment says what goes there (What), what a strong entry has (Good)
     and an example (Example). Delete each comment when you fill its
     section. When the input left nothing open, replace everything below
     the title with the line "No open questions: <why>". -->

PRD: docs/product/PRD.md   Updated: <date>
Entries: N   Open: O   Needs your confirmation: A

Basis, for every entry:
- stated: the input answers it elsewhere; the passage that wins is named.
- inferred: only one reading is consistent with the rest of the input.
- convention: the input is silent and the team's standards settle it.
- assumption: nothing settles it; a choice was made so the team is not blocked.

## Needs your confirmation

<!-- What: one line per open entry whose Basis is assumption: the id, the
     question in a clause, and what was assumed.
     Good: exactly the open assumption rows of the register, no more; a
     reader who answers only these has unblocked the backlog. The gate
     fails an open assumption missing here, or an id here that is not one.
     Example: "- Q-004 Which lab formats are accepted? Assumed: PDF only;
     other formats are refused with a message (US-00-014, US-00-016)." -->

- Q-nnn <the question, one clause>. Assumed: <the decision>. (<US ids>)

## Register

<!-- What: one row per open point, open assumptions first, then the rest by
     id.
     Good: Kind is open-question (the input asks it), gap (the input is
     silent) or contradiction (two passages disagree, both named in Where);
     Where is the REQ id or the PRD section; Basis is stated, inferred,
     convention or assumption; Readings lists every reading, lettered;
     Decision is the reading taken, written so work can start; Why says what
     settled it; Affects names the story ids it changes and is never empty
     (prd writes the REQ ids until backlog replaces them); Status is
     open until the client confirms, then confirmed. A confirmed decision
     the client later reverses keeps its row and gains a dated "reversed
     on <date>" note pointing at the entry or REQ that records the new
     answer.
     Example: "Q-004 | open | gap | REQ-019 | assumption | Which lab formats
     are accepted? | (a) PDF only; (b) PDF and images; (c) any attachment |
     (a) PDF only; others refused with 'Cannot read this file' | the brief
     shows only PDF samples | US-00-014, US-00-016" -->

| Q | Status | Kind | Where | Basis | Question | Readings | Decision | Why | Affects |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q-001 | open | open-question / gap / contradiction | REQ-nnn or section | stated / inferred / convention / assumption | <the question> | (a) <reading>; (b) <reading> | <the reading taken> | <what settled it> | US-nn-nnn |
