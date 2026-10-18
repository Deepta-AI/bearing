# Recipes by goal

Each recipe names the goal it serves, the data it needs, the defaults,
and the sign it was the wrong choice. Toolchain is Hugging Face TRL with
PEFT unless stated; Axolotl runs the same recipes from a YAML file.

## Decision table

| Goal | Recipe | Data | Minimum examples | Wrong choice when |
| --- | --- | --- | --- | --- |
| Consistent style, format, schema adherence | LoRA SFT | prompt and ideal response | 500 | a structured-output schema or a two-shot prompt already does it |
| Better judgement between plausible answers | DPO (or ORPO) | prompt, chosen, rejected | 1,000 pairs | the preference is really a rule you can state in the prompt |
| Same quality at a fraction of the cost | Distillation (SFT on teacher outputs) | prompts from real traffic, teacher responses | 2,000 | volume is under 100K requests a month; the API model at lower effort is cheaper than serving |
| Domain vocabulary the base model lacks | Continued pretraining, then SFT | raw domain text | 50M tokens | RAG can bring the vocabulary in at read time; almost always |

## LoRA SFT (style, format)

- Base: instruction-tuned checkpoint of the chosen family, the smallest
  size that clears the baseline on the golden set with a good prompt.
- LoRA: `r=16`, `alpha=32`, `dropout=0.05`, target all linear
  projections. QLoRA (4-bit base) when the GPU has under 24 GB.
- Training: learning rate `2e-4`, cosine schedule, warmup 3 percent,
  batch of 16 sequences (gradient accumulation to reach it), 2 to 3
  epochs, max sequence length from the p95 of the data plus margin.
- Loss on assistant turns only (`assistant_only_loss` in TRL's
  `SFTTrainer`, or the equivalent template masking).
- Stop when validation loss rises for 2 evaluations.
- Sign of trouble: training loss near zero by epoch 1 (memorising;
  data too small or duplicated).

## DPO (judgement)

- Start from the SFT checkpoint, not the base.
- Pairs come from a person choosing between two model outputs, or from
  the eval judge with a person checking 20 percent.
- `beta=0.1`, learning rate `5e-6`, 1 to 2 epochs, LoRA as above.
- Track the reward margin on validation; a margin that grows while the
  eval score falls means the pairs encode a style, not a judgement.
- ORPO when there is no SFT stage and the pairs are plentiful.

## Distillation from Claude (cost)

- Teacher: `claude-opus-5` for the response quality the product needs;
  `claude-sonnet-5` when the task is narrow (classification, extraction)
  and the eval shows no gap between the two.
- Prompts: real traffic with PII removed, deduplicated, stratified by
  the tags the eval uses. Generate teacher responses through the
  gateway with the production prompt; use the Message Batches API for
  half the price when latency does not matter.
- Filter teacher outputs with the deterministic graders before
  training; a wrong teacher answer teaches the wrong thing.
- Student: 1B to 8B instruction-tuned open model, LoRA SFT as above.
- The teacher route stays configured as the fallback in
  `llm/routing.yaml`; the student earns traffic through the canary.
- Cost model to put in the ADR: teacher cost per 1K requests vs student
  serving cost per 1K at the expected volume, plus the one-off teacher
  spend to build the dataset.

## Continued pretraining (vocabulary)

- Only with an ADR that shows RAG failed to bring the vocabulary in.
- Full-parameter or high-rank LoRA on raw domain text, learning rate
  `1e-5`, 1 epoch, then the SFT recipe to restore instruction
  following.
- Expect to lose general capability; the eval must include general
  cases to see it.

## Compute estimate

```
train FLOPs = 6 x parameters x tokens x epochs
GPU hours   = train FLOPs / (GPU peak FLOPs x utilisation 0.35) / 3600
```

LoRA trains a fraction of the parameters but the forward and backward
pass still touches the base; use the full parameter count for the
estimate and expect the LoRA run to be about 30 percent faster.

## Evaluation protocol

1. `make eval EVAL=<name>` on the test split with the prompt-only path.
   Record as baseline.
2. Same command against the base model with the same prompt. Record.
3. Same command against each checkpoint. Record.
4. Ship only a checkpoint that beats step 1 by more than the noise
   floor on the primary metric without losing on the others.

## Toolchain notes

- TRL: `SFTTrainer` and `DPOTrainer` with `peft.LoraConfig`; one Python
  file per recipe under `training/`, a `make train-<recipe>` target that
  prints the config and refuses to start without `CONFIRM=1`.
- Axolotl: one YAML per recipe under `training/axolotl/`; same refusal.
- Both write checkpoints and the run config to `runs/<name>/<date>/`;
  the model card links the run directory.
