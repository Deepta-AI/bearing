---
name: llm-fine-tuning
description: 'Fine-tunes an open model when prompting and RAG fall short: eval-backed decision, dataset, LoRA, DPO or distillation, vLLM serving. Use when asked to "fine-tune a model", "train on our data" or "distil a smaller model".'
argument-hint: "<name> [sft|dpo|distil|cpt]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(wc -l:*), Bash(python3 -c:*), Bash(make eval:*), Bash(git log:*), Bash(uv run train_sft.py --smoke:*), Bash(nvidia-smi:*), Bash(python3 *skills/llm-fine-tuning/scripts/gpu_check.py*)
---

# llm-fine-tuning

Anthropic models are used through the API and are not fine-tuned by us.
Training means an open model, and it is the last lever, pulled only when
an eval shows the gap that prompting, retrieval and a stronger model
could not close. This skill writes the plan, the data and runnable
training code, proves the pipeline with a smoke run of a few minutes,
and serves the result behind the gateway. The full run is started by a
person on the hardware the plan names.

Not this: submitting jobs to Hugging Face Jobs is `huggingface-llm-trainer`
and the plain TRL command line is `trl-training` (huggingface-skills,
official marketplace); use them for the run itself when the team trains
there, and keep this skill's decision, data, eval and serving steps.

## Inputs

- Eval scores: `docs/genai/evals.md` and `evals/<name>/results/`; if
  absent, asks the user for the current score and the target; if they
  have none, runs `llm-eval`'s minimal path inline: ten labelled
  cases in `evals/<name>/cases.jsonl`, one deterministic grader, one run
  on the current prompt path. That score is the number to beat, marked
  `minimal`; the full set is an `llm-eval` follow-up.
- Solution doc: `docs/genai/<name>-solution.md`; if absent, asks the
  task, the volume per day and the model in use in one question.
- Data sources: logs, owner-written examples or a teacher model; if none
  exist yet, the plan names how to collect them and the data section
  reports zero counts under Not done.
- Gateway routing: `llm/routing.yaml`; if absent, step 6 is written as a
  plan and the route is an `llm-gateway` follow-up.

## Steps

1. Name from `$1`, goal from `$2` or asked. Read `docs/genai/evals.md`
   for `<name>`. No eval, or no accepted baseline: the Inputs fallback
   (ask, else the minimal path). Training without a number to beat is
   not allowed, so the minimal run happens before step 2.
2. The decision, written as an ADR (`adr Train <name> with <recipe>`,
   or a file in `docs/adr/`) with the evidence table: score with the current prompt, with the
   prompt tuned (`prompt-registry`), with RAG (`rag`), with
   `claude-opus-5` at higher effort, and the cost per 1K requests of
   each. Training is justified when the best of those misses the
   target, or hits it at a cost per request the product cannot carry.
   Say which. Recipe by goal from `references/recipes.md`: style and
   format, LoRA SFT; judgement between candidates, DPO; cost at volume,
   distil from `claude-opus-5` into a small open model; domain
   vocabulary, continued pretraining (its own ADR, rarely justified).
3. Data. Collection sources (logs with consent, owner-written, the
   teacher model for distillation), the labelling guide
   (`docs/genai/labelling-<name>.md`: one page, three worked examples,
   the edge cases), PII removal with a named function and a test,
   exact and near-duplicate removal (hash, then MinHash at 0.85), and a
   split of 80/10/10 into train, validation and test with no document
   shared across splits. Format is chat messages JSONL from
   `templates/dataset.jsonl`. The test split is the golden set from
   `llm-eval`, never training data. Print counts at every stage.
4. Run plan in `docs/genai/training-<name>.md`: base model (current
   open families: Qwen3, Llama 4, Gemma 3; pick the size the serving
   budget allows and name the exact checkpoint), toolchain (Hugging
   Face TRL with PEFT by default: plain Python, testable, one file per
   recipe; Axolotl when the team already runs it and wants YAML-driven
   multi-GPU jobs), hyperparameters with the defaults from the recipe,
   compute estimate (tokens x epochs x 6 x parameters FLOPs, then GPU
   hours at a stated utilisation), checkpoints every epoch, early
   stopping on validation loss with patience 2, seeds fixed. Copy
   `templates/train_sft.py` to `ml/<name>/train_sft.py` and fill the
   base checkpoint and its tiny smoke sibling (DPO and distillation
   change the trainer class, not the shape).
5. Hardware and smoke run. Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/llm-fine-tuning/scripts/gpu_check.py" --params-b <p> --method <lora|qlora|full>`
   and copy its `gpu-check:` line; when it does not fit, pick QLoRA, a
   smaller base, or name the cloud GPU in the plan. Then
   `uv run train_sft.py --smoke` (20 steps on 64 examples; the tiny base
   on CPU when there is no GPU). It must finish, save an adapter and
   report an eval loss. A smoke run that fails is the finding; the full
   run waits for it.
6. Evaluation: the same eval run (`make eval EVAL=<name>`, or the
   harness directly) on the test split
   before (base model, prompt-only path) and after. Report both. A
   post-training score that does not beat the prompt-only path by more
   than the noise floor means the model does not ship.
7. Deployment: serving from `templates/serve-vllm.md` (vLLM with the
   adapter as a LoRA module, OpenAI-compatible, behind the gateway as a
   `vllm` provider), or a managed endpoint; the route in `llm/routing.yaml`
   (the plan's route table when no gateway exists) with `canary: 5`
   percent, the metric that decides (eval score on sampled traffic plus
   error rate), and rollback to the prompt-only route as a config
   change. Distilled models keep the teacher route as the fallback.
8. Model card `docs/genai/model-card-<name>.md` from
   `templates/model-card.md`. Every section filled; "not evaluated" is
   an allowed answer, blank is not.
9. Print the contract.

## Output contract

```
## Training plan: <name> (<recipe>)
decision: docs/adr/NNNN-..., gap <x.xx> vs target <y.yy> at <cost> per 1K
examples: <N> collected, <M> after dedup and PII removal, split <train>/<val>/<test>
data: data/<name>/{train,valid,test}.jsonl, guide docs/genai/labelling-<name>.md
run: docs/genai/training-<name>.md (<base model>, <toolchain>, <GPU hours> est.)
hardware: <gpu-check line, verbatim>
smoke: <passed, eval_loss x | FAILED at <step>>   full run: <not started | runs/<name>/full>
baseline score: <x.xx> (prompt-only, <model>)   post-training: <not run | y.yy>
deploy: vLLM <base> + <name>-v1, route <name> canary <p>%, rollback to <route>
model card: docs/genai/model-card-<name>.md
```

## Gotchas

- Run the kit's scripts from the kit path while working. When the repo
  wants a make target or CI job for a check, copy the script into the
  repo's `scripts/` and point the target there; a target that names the
  kit's own path breaks on every other machine.
- Anthropic models are not fine-tunable by us. A request to "fine-tune
  Claude" becomes prompt tuning, RAG, or distillation into an open
  model; say so plainly.
- Distillation uses a teacher's outputs as training data. Confirm the
  current Anthropic usage policy allows the intended use and record
  the check in the ADR.
- Fewer than 500 clean examples for SFT or 1,000 pairs for DPO rarely
  beats a good prompt on Sonnet 5. Measure before spending GPU hours.
- Test-split leakage is the most common false win. Dedup across splits
  by document, not by example.
- A LoRA that improves format and hurts accuracy still fails; the eval
  has both metrics, report both.
- Never train on data that contains PII, secrets, or content the
  client did not license for training.
- The skill runs the smoke job only. A person starts the full run on
  the hardware the plan names, never against production.
- A GPU that fits the model at batch 1 can still run out of memory at
  the planned sequence length. The smoke run uses the real max length.
