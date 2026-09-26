#!/usr/bin/env python3
"""gpu_check: before a training run, show the GPUs this machine has and
whether the planned model and method fit in memory, so a run is not
started on hardware that will fail an hour in.

Reads `nvidia-smi --query-gpu=name,memory.total,memory.free
--format=csv,noheader,nounits` (the command can be replaced with the
NVIDIA_SMI environment variable, which the tests use). Memory needed is
estimated from the parameter count in billions and the method, per GPU:
  qlora  0.7 GB per billion parameters (4-bit weights, adapters, activations)
  lora   2.4 GB per billion (bf16 weights, adapters, activations)
  full   18 GB per billion (bf16 weights, fp32 optimiser states, gradients)
  infer  2.2 GB per billion (bf16 serving with a modest KV cache)
plus 2 GB headroom. The estimate is a floor at batch size 1 and a short
sequence; long sequences need more.

Usage: gpu_check.py --params-b 7 --method lora [--allow-cpu]
Prints one line per GPU, then
  gpu-check: G GPUs, best <name> <free> GB free, need ~<n> GB for <method> on <p>B: fits | does not fit
and exits 1 when no GPU is found (unless --allow-cpu, for a tiny smoke
run on CPU), or the planned run does not fit on the best GPU.
"""

import argparse
import os
import shlex
import subprocess
import sys

PER_B = {"qlora": 0.7, "lora": 2.4, "full": 18.0, "infer": 2.2}
HEADROOM = 2.0


def gpus():
    cmd = os.environ.get("NVIDIA_SMI", "nvidia-smi")
    try:
        out = subprocess.run(
            shlex.split(cmd)
            + [
                "--query-gpu=name,memory.total,memory.free",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    found = []
    for line in out.stdout.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) == 3:
            try:
                found.append((parts[0], float(parts[1]) / 1024, float(parts[2]) / 1024))
            except ValueError:
                continue
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--params-b", type=float, required=True)
    ap.add_argument("--method", choices=sorted(PER_B), required=True)
    ap.add_argument("--allow-cpu", action="store_true")
    args = ap.parse_args()

    need = args.params_b * PER_B[args.method] + HEADROOM
    found = gpus()
    for name, total, free in found:
        print(f"gpu: {name}, {total:.1f} GB total, {free:.1f} GB free")
    if not found:
        verdict = "cpu smoke only" if args.allow_cpu else "does not fit"
        print(
            f"gpu-check: 0 GPUs, need ~{need:.1f} GB for {args.method} on {args.params_b:g}B: {verdict}"
        )
        return 0 if args.allow_cpu else 1
    best = max(found, key=lambda g: g[2])
    fits = best[2] >= need
    print(
        f"gpu-check: {len(found)} GPUs, best {best[0]} {best[2]:.1f} GB free, "
        f"need ~{need:.1f} GB for {args.method} on {args.params_b:g}B: {'fits' if fits else 'does not fit'}"
    )
    return 0 if fits else 1


if __name__ == "__main__":
    sys.exit(main())
