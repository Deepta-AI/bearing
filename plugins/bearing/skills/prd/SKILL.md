---
name: prd
description: 'Normalises any brief, notes or ticket into a PRD of numbered testable REQ statements, objectives, personas and open questions; no stories. Use when asked to "write the PRD" or "turn this brief into requirements".'
argument-hint: "<attach the brief, give its path, or paste it in the message>"
allowed-tools: Read, Write, Grep, Glob, Agent, Bash(ls:*), Bash(mkdir:*), Bash(wc:*), Bash(git rev-parse:*), Bash(python3 *skills/prd/scripts/doc_to_text.py*)
---

# prd

The PRD is the root of the traceability chain. Every `REQ-nnn` written here
is carried by stories, criteria, tests and commits, so the skill extracts
only what the input says, marks what it had to infer, and never renumbers.

Not this: pm-skills `create-prd` writes an eight-section product
document from scratch; this normalises any input into a PRD on this
standard, whose numbered REQ statements are intents to be judged and
combined by `backlog`, never one story per line.

## Inputs

- Product input: looks in `$1` as a file path, then a document attached
  to the message (the app hands over its path, or inlines a text file,
  which counts as pasted), then the text of the
  message, then `docs/product/PRD.md` to re-normalise; if absent, looks in
  `README.md` and `docs/**/*.md` for a brief or a feature list and, when
  none describes the product, asks one question for an attached
  document, a pasted brief or a file path. Nothing after that stops the skill: "provide a brief, a file
  path or an existing PRD".
- Existing PRD: looks in `docs/product/PRD.md` for ids to keep; if absent,
  numbering starts at `REQ-001`.
- Templates: `templates/PRD.md` and `templates/questions.md` in this
  skill; no repository copy is needed.
- Existing register: looks in `docs/product/questions.md` for Q ids and
  decisions to keep; if absent, numbering starts at `Q-001`.
- Input format: `.md`, `.txt`, `.html` and pasted text are read as they
  are; a `.pdf` is read with Read (20 pages per call); a `.docx` or `.odt`
  is converted by `scripts/doc_to_text.py` in this skill (standard library
  Python). Only a legacy `.doc`, a Google Doc or a Notion link gets one
  question asking for a `.docx`, PDF or text export.
- Target repository: the git repository the session runs in
  (`git rev-parse --show-toplevel`). When the working directory is not
  one, or is a folder holding several repositories, ask one question for
  the product's repository path; never write `docs/product` into a parent
  folder.
- Repository decisions: `docs/adr/*.md` (or wherever the README keeps
  decisions) and the code that already handles the domain; if absent, the
  input is checked against itself only and the report says so.
- Existing stories: looks in `docs/product/stories.md` (or the tracker
  export the README names) for the story ids that carry each REQ; if
  absent, Affects stays on REQ ids.

## Steps

1. Locate the input in the order under Inputs and save its text as
   `docs/product/source/<input name>.txt` (`mkdir -p docs/product/source`),
   so every REQ's Source cites `L<n>` of a file in the repository: a
   `.docx` or `.odt` with `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/prd/scripts/doc_to_text.py" <input>
   docs/product/source/<input name>.txt` (it fails on a document with no
   text), a PDF, an attachment or a paste with Write, a repository file
   cited where it is. Print its size (`wc -l`) and its source. A README or a docs page used
   as the brief is named as the source so the reader knows the PRD was
   inferred from it.
2. Read `templates/PRD.md` and `templates/questions.md`. If `docs/product/PRD.md` exists, read it and
   keep every existing `REQ-nnn` id and text; new statements append after
   the highest id in the whole file (ids are not always in order in the
   tables), withdrawn statements stay in the list marked `withdrawn:`.
   Never renumber. When the input changes an existing statement, apply
   step 7a.
3. First pass, sections. Fill problem, business objectives, non-goals,
   personas, constraints, glossary from the input only. Objectives get ids
   `B1` upward, kept across runs; every story's "Why it matters" line
   cites one. An objective with no number in the input gets
   `target: unconfirmed`. A persona is a named role in the
   input; if none is named, derive at most one from the verbs and mark it
   `inferred:`. Any section the input does not cover is written as
   "Not in the input" and listed under Could not extract.
4. Second pass, statements. Walk every sentence carrying must, should,
   shall, needs, can, will, allow, or an imperative, and every bullet.
   Each becomes one `REQ-nnn`: one testable statement, present tense,
   the system as subject. Split a sentence joining two capabilities with
   "and". Convert story form ("As a user I want") to a statement and keep
   the persona. Keep a solution only if the input names it, then move it
   to Constraints. Record the source line or quote next to each REQ.
5. Flag ambiguity. A statement with a vague word (fast, easy, simple,
   appropriate, etc., some, various) or with no observable outcome is
   kept, marked `ambiguous:`, and gets one entry in the register stating
   what would make it testable.
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
   handling, what happens when a service is down, uniqueness rules) is
   not a client requirement: it goes to the register as a team proposal
   with Basis `convention` or `assumption`, or is left to design, never a
   REQ in the client's voice. Details the input leaves out of a new
   capability (amounts, limits, validity, refund rules) stay open
   questions; do not choose them. Numbers the input derives (a reward
   every Nth visit from an average bill) are recomputed, and any
   alternative offered to the client is recomputed too.
7. Write the register from `templates/questions.md`: per entry the Kind
   (open-question, gap, contradiction), Where (the REQ id or section),
   Basis (stated, inferred, convention, assumption), every reading the
   input allows, the Decision taken so work is not blocked, Why, Affects
   (the REQ ids it changes; `backlog` replaces them with story ids,
   and the cell is never empty) and Status `open`. Open assumptions go
   first and are listed again under "Needs your confirmation". Keep the
   ids and decisions of an existing register; a confirmed entry stays,
   and an entry the new input does not touch keeps its text. A new entry
   is written only for a point a reader must answer or know; a doubt that
   changes no decision is not an entry.
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
8. Write `docs/product/PRD.md` and `docs/product/questions.md`
   (`mkdir -p docs/product`); section 7 of the PRD states the register's
   counts. Print the counts. Zero statements extracted is a failed run,
   not an empty PRD.
9. Ask the user whether to run the critic. On yes, fork `critic`
   (Agent tool) with the document path; add its three weakest claims and
   what the document does not say to the register, each as a Q-nnn whose
   Readings include the experiment that would settle it.

## Output contract

```
## PRD: <title> (<N> input lines from <source>)
Statements extracted: S (REQ-001 to REQ-nnn, W withdrawn)
Business objectives: B (B1 to Bn, T with a confirmed target)
Ambiguous statements flagged: K   Inferred items: J
Register: Q entries (open-question O, gap G, contradiction C);
          needs your confirmation A
Could not extract: <sections, or none>
Changed: withdrawn <ids>, replaced <old -> new>, new <ids>, reversed <Q ids> | first PRD
Affected downstream: <story ids with status, code/test files citing the ids> | none
Written: docs/product/PRD.md, docs/product/questions.md
Critic: run (K claims, verdict <line>) | declined
Verdict: normalised | failed (0 statements)
```

## Gotchas

- A PRD line is a statement of intent, not a story. Do not write "As a"
  anywhere in the statements list; `backlog` judges and combines them.
- A number in the input is a target only if the input calls it one. A
  budget, a launch date or a user count from the brief goes to Constraints.
- Two inputs (an old PRD and a new brief) never merge their numbering; the
  new brief's statements append after the existing ids.
- An assumption is a decision nobody has confirmed. It goes under "Needs
  your confirmation" so the client sees it first; a decision the input
  settles is `stated` or `inferred` and names the passage.
- Do not tidy the client's wording into your own product idea. When the
  input says "the app should feel premium", that is an ambiguous
  statement and an open question, not three requirements about animation.
