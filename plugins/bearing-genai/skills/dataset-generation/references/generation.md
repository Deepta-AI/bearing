# Generation methods

How `dataset-generation` turns a seed and a taxonomy into rows a person
can audit. The gate is `scripts/dataset_check.py`; nothing here replaces
it.

## Row shapes

Write rows in the shape their consumer already reads, so the gate and
the consumer agree:

- `eval`: `llm-eval`'s case row: `id`, `task`, `input` (an object, as in
  `llm-eval/templates/cases.jsonl`), `expected` or `rubric`, `tags`,
  `source: synthetic`, plus `cell` and `meta`. `labelled_by` and
  `labelled_at` are set at promotion, from the audit.
- `train`: `llm-fine-tuning`'s chat row: `id`, `source: synthetic`,
  `messages` (system, user, assistant), `tags`, `cell`, `meta`.
- `preference`: `id`, `source`, `prompt` (chat turns), `chosen`,
  `rejected`, `cell`, `meta`.

`meta` holds `generator` (the model id from the response, not the
config), `prompt` (`<name>-generate` and its version) and `batch` (the
run date and a counter). The datasheet's Generation section is built
from these fields.

## The generation prompt

One file under `bearing-genai:prompt-registry`, `<name>-generate`, with a
version that changes whenever the text changes. It carries:

1. The product in two sentences, from the solution doc.
2. The target cell, every dimension named with its value, and what that
   value means ("code-mixed: Hindi and English in one sentence, Latin
   script").
3. Three to five seed rows as examples, rotated per call and drawn from
   other cells where the target cell has none, so the generator varies
   the content rather than copying one example.
4. The rows already kept for that cell (their first lines), with "write
   rows unlike these".
5. The output schema, by structured output, never a prefilled reply
   (current Claude models reject prefill; the `claude-api` skill has the
   shape).
6. For `eval` rows, the label or rubric the generator proposes and a
   one-line reason; the audit checks both.

Variety comes from the cell, the rotated examples and the kept-row list.
Do not reach for sampling parameters: several current models reject
`temperature` and `top_p` (the `claude-api` skill's thinking table).

## Per kind

- `eval`: ask for the case and its expected answer separately when the
  answer needs reasoning, so a wrong label is visible in the audit.
  Adversarial cells hold prompt injection, out-of-scope requests and
  inputs at the length limit, never real customer content.
- `train`: the teacher writes the assistant turn for real or generated
  user turns. Real user turns with a teacher answer are better rows than
  wholly synthetic ones; prefer them where the seed allows.
- `preference`: `chosen` from the teacher, `rejected` from the model
  being trained or a weaker one on the same prompt. A pair where both
  answers are good teaches nothing; the audit rejects it.
- Harder rows: rewrite a kept row to add one constraint, one distractor
  or one missing field, and give it the next difficulty value.

## generate.py

`datasets/<name>/generate.py`, plain Python, run with
`uv run python datasets/<name>/generate.py --target <N>`. It:

1. reads `taxonomy.json`, the seed and any rows already in
   `generated.jsonl` (a re-run tops up cells, it does not start over);
2. for each cell short of its target, calls the gateway's `complete()`
   on the `dataset-<name>` route with the prompt above, in batches of 5
   to 10 rows per call;
3. parses the structured output, drops rows that fail the schema
   (counted), stamps `source`, `cell` and `meta`, and appends;
4. prints one count line from the gateway's usage record:
   `generate: <G> rows written, <F> failed the schema, cost $<C>`.

No gateway in the repository: the script calls the provider SDK the
project already uses, records the model id from the response, and the
report says the calls are outside the gateway.

## Filtering loop

`dataset_check.py` prints one line per problem with the row id. Rows it
names as exact or near duplicates (5-gram Jaccard at or above 0.8, the
one threshold), contaminated or missing a field are dropped; the rest go
to `rows.jsonl`. Run the gate again on `rows.jsonl`: its count line is
the one the contract and the datasheet copy. A cell left empty after one
top-up goes in the datasheet's Filtering section as a gap.

## Audit sample

Required count from the gate: the smaller of the synthetic rows and
`max(30, ceil(0.2 x synthetic))` for kind `eval` (`llm-eval`'s rule
that a person checks 20 percent of model-labelled cases), or
`max(30, ceil(0.1 x synthetic))` for `train` and `preference`. Draw it
with a fixed seed, stratified by cell (each cell's share of the sample
follows its share of the rows, at least one per filled cell), into
`audit-sample.jsonl`. The person reads input, label or answer, and
writes `accept` or `reject` with `why`. Someone other than the author
of the generation prompt audits where the team allows it.

At 90 percent or more accepted the batch passes; rejected rows are
dropped. Below 90 percent the whole batch is regenerated: the rejection
reasons go into the next prompt version, and the new batch gets a fresh
sample.
