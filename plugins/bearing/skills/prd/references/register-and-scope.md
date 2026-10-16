# prd: the register entry, the ambiguity flag and the PRD boundary

Read when you write register entries (step 7) or flag a vague statement (step 5).

5. Flag ambiguity. A statement with a vague word (fast, easy, simple,
   appropriate, etc., some, various) or with no observable outcome is
   kept and marked `ambiguous: acceptance set in design`: design and
   `test-cases` give it a measurable acceptance, and it is not a
   question. Only when the vague word leaves the scope itself unclear
   (what gets built, not how well) does it get a register entry, marked
   `ambiguous: Q-nnn`, and statements one answer settles share that entry.

7. Write the register from `templates/questions.md`: per entry the Kind
   (open-question, gap, contradiction), Where (the REQ id or section),
   Basis (stated, inferred, convention, assumption), every reading the
   input allows, the Decision taken so work is not blocked, Why, Affects
   (the REQ ids it changes; `backlog` replaces them with story ids,
   and the cell is never empty) and Status `open`. Open assumptions go
   first and are listed again under "Needs your confirmation". Keep the
   ids and decisions of an existing register; a confirmed entry stays,
   and an entry the new input does not touch keeps its text. A new entry
   is written only where the input is unclear or contradicts itself about
   what the product does, and the answer changes what gets built; a
   doubt that changes nothing built is not an entry. A long register is
   a sign the skill is reviewing the idea instead of recording it.

Not this: pm-skills `create-prd` writes an eight-section product
document from scratch; this normalises any input into a PRD on this
standard, whose numbered REQ statements are intents to be judged and
combined by `backlog`, never one story per line.

- Input format: `.md`, `.txt`, `.html` and pasted text are read as they are; a
`.pdf` is read with Read (20 pages per call); a `.docx` or `.odt` is
converted by `scripts/doc_to_text.py` in this skill (standard library
Python). Only a legacy `.doc`, a Google Doc or a Notion link gets one
AskUserQuestion, options "enter the path of a `.docx`, PDF or text export"
(via Other) and "stop".
