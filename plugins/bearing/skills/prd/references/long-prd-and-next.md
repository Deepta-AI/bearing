# A long PRD, and the step after it

## Over 60 statements: parts per area

One PRD.md with hundreds of statements is hard to read and costly to load
in every later step. Past 60 live statements (withdrawn ones do not count),
section 5 moves out of PRD.md into parts, one per top-level area of the
input:

```
docs/product/PRD.md                  sections 1 to 4 and 6 to 9 in full,
                                     section 5 as an index of the parts
docs/product/prd/01-booking.md       the statements table for one area
docs/product/prd/02-payments.md      ...
```

- A part is the same table as section 5 (Id, Statement, Persona, Source,
  Flags), headed `# <area>: REQ-nnn to REQ-mmm`. Ids never change when a
  statement moves to a part, and a part never restarts numbering: new
  statements still append after the highest id in PRD.md and every part.
- Section 5 of PRD.md keeps one row per part: area, file, REQ range and
  count, as the template shows. Statements stay in exactly one place, never
  copied into both.
- Areas come from the input's own top-level headings, in its order; `nn` is
  that order, two digits. A heading with fewer than five statements joins
  its neighbour rather than getting a part of its own.
- The backlog coverage check, the traceability check and the autopilot gate
  read PRD.md and then `docs/product/prd/*.md` in name order, so nothing
  downstream changes. The client pack takes only the title, from PRD.md.
- Re-running on a split PRD: read every part for ids to keep, apply step 7a
  in the part that holds the statement, and add a new area as a new part.
- At 60 or fewer the PRD stays one file: a part split for a small PRD costs
  more navigation than it saves.

## The next step

The reply ends with one `Next:` line, so a reader new to the workflow knows
what to run:

- `backlog`: judges and combines the statements into epics, stories and
  acceptance criteria, every live REQ covered or ruled out of scope. This is
  the next step for every PRD.
- `bearing-genai:genai-design` first, then `backlog`, when the product's
  behaviour depends on a model: a chat or voice assistant, an LLM writing or
  summarising, retrieval over documents (RAG), an agent taking actions, a
  classifier or scorer. It decides the model, the evaluation set and the
  guardrails the stories then cite. When the bearing-genai plugin is not
  installed, say so and give `/plugin install bearing-genai@bearing`.
- The register comes before either: open questions are asked in step 10, and
  the `Next:` line follows the answers, not the other way round.
- `workflow` shows the rest of the path (the greenfield flow from an idea:
  prd, backlog, estimate, tech-decision, high-level-design and on).
