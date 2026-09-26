# /// script
# requires-python = ">=3.11"
# dependencies = ["trl>=0.20", "peft>=0.15", "transformers>=4.55", "datasets>=3.0", "accelerate>=1.0"]
# ///
"""LoRA SFT for <name>, copied from llm-fine-tuning's template.

Smoke run (proves the data, the chat template and the save path; minutes):
    uv run train_sft.py --smoke
Full run (started by a person on the GPU the plan names):
    uv run train_sft.py

Data: data/<name>/{train,valid}.jsonl in chat messages format, one
{"messages": [{"role": "system"|"user"|"assistant", "content": "..."}]} per line.
The test split is never read here; it belongs to the eval harness.
"""

import argparse
import json
import pathlib
import random

from datasets import load_dataset
from peft import LoraConfig
from trl import SFTConfig, SFTTrainer

NAME = "<name>"
BASE = "<exact base checkpoint, e.g. Qwen/Qwen3-1.7B>"
SMOKE_BASE = (
    "<a tiny checkpoint of the same family for CPU smoke runs, e.g. Qwen/Qwen3-0.6B>"
)
DATA = pathlib.Path("data") / NAME
OUT = pathlib.Path("runs") / NAME
MAX_LEN = 2048  # the planned sequence length; the smoke run uses it too


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--smoke",
        action="store_true",
        help="20 steps on 64 examples, tiny base if no GPU",
    )
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    random.seed(args.seed)

    ds = load_dataset(
        "json",
        data_files={
            "train": str(DATA / "train.jsonl"),
            "valid": str(DATA / "valid.jsonl"),
        },
    )
    if args.smoke:
        ds["train"] = ds["train"].select(range(min(64, len(ds["train"]))))
        ds["valid"] = ds["valid"].select(range(min(16, len(ds["valid"]))))
    print(f"data: train {len(ds['train'])}, valid {len(ds['valid'])}")

    try:
        import torch

        on_gpu = torch.cuda.is_available()
    except ImportError:
        on_gpu = False
    base = BASE if (on_gpu or not args.smoke) else SMOKE_BASE

    config = SFTConfig(
        output_dir=str(OUT / ("smoke" if args.smoke else "full")),
        num_train_epochs=3,
        max_steps=20 if args.smoke else -1,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        logging_steps=5,
        eval_strategy="steps" if args.smoke else "epoch",
        eval_steps=10,
        save_strategy="epoch",
        load_best_model_at_end=not args.smoke,
        metric_for_best_model="eval_loss",
        bf16=on_gpu,
        seed=args.seed,
        max_length=MAX_LEN,
        report_to="none",
    )
    lora = LoraConfig(
        r=16,
        lora_alpha=32,
        lora_dropout=0.05,
        target_modules="all-linear",
        task_type="CAUSAL_LM",
    )
    trainer = SFTTrainer(
        model=base,
        args=config,
        train_dataset=ds["train"],
        eval_dataset=ds["valid"],
        peft_config=lora,
    )
    trainer.train()
    trainer.save_model(config.output_dir)
    metrics = trainer.evaluate()
    (OUT / "last-run.json").write_text(
        json.dumps({"base": base, "smoke": args.smoke, **metrics}, indent=2)
    )
    print(
        f"train: saved adapter to {config.output_dir}, eval_loss {metrics.get('eval_loss')}"
    )


if __name__ == "__main__":
    main()
