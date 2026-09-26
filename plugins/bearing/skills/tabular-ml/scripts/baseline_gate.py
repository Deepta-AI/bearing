#!/usr/bin/env python3
"""baseline_gate: a trained model ships only when it beats the simple
baseline on the test split by more than the stated margin.

Reads a metrics JSON file written by the training run:
  {"baseline": {"name": "recency rule", "auc": 0.66, "precision_at_10": 0.21},
   "model":    {"name": "lgbm-v3",      "auc": 0.74, "precision_at_10": 0.34}}
and compares one metric.

Usage: baseline_gate.py metrics.json --metric auc [--min-lift 0.02] [--lower-is-better]
Prints
  ml-baseline: <metric> baseline <b> (<name>), model <m> (<name>), lift <d>, gate <g>: pass | FAIL
and exits 1 when the file lacks either block or the metric, or the model
does not beat the baseline by more than --min-lift (for --lower-is-better
metrics such as MAE, lift is baseline minus model).
"""

import argparse
import json
import sys


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("metrics")
    ap.add_argument("--metric", required=True)
    ap.add_argument("--min-lift", type=float, default=0.0)
    ap.add_argument("--lower-is-better", action="store_true")
    args = ap.parse_args()

    with open(args.metrics, encoding="utf-8") as fh:
        data = json.load(fh)
    try:
        b = float(data["baseline"][args.metric])
        m = float(data["model"][args.metric])
    except (KeyError, TypeError, ValueError):
        print(
            f"ml-baseline: {args.metric} missing from the baseline or model block of {args.metrics}"
        )
        return 1
    lift = (b - m) if args.lower_is_better else (m - b)
    ok = lift > args.min_lift
    print(
        f"ml-baseline: {args.metric} baseline {b:.4g} ({data['baseline'].get('name', 'baseline')}), "
        f"model {m:.4g} ({data['model'].get('name', 'model')}), lift {lift:.4g}, gate {args.min_lift:.4g}: {'pass' if ok else 'FAIL'}"
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
