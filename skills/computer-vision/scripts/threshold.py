#!/usr/bin/env python3
"""threshold: AUROC and the operating threshold of a vision model's scores,
chosen from what a miss and a false reject cost, so the pass or fail line
in computer-vision's report is computed from the evaluation set, not guessed.

Input is CSV with a header and at least the columns `label` and `score`:
  id,label,score
  img-001,1,0.93
`label` 1 is the positive class (a defect, the object present), 0 the
negative; a higher `score` means more likely positive. Extra columns are
ignored. Use it on the validation split to choose, then on the test split
with --at to report.

The threshold minimises  miss_cost * FN + reject_cost * FP  over every
distinct score (ties broken toward the higher recall).

--prevalence gives the positive rate where the model will run. An evaluation
set that was enriched with defects (or thinned of them) has the wrong mix, and
the cost-optimal threshold moves with the mix; with --prevalence each positive
is weighted by prevalence / sample rate and each negative by
(1 - prevalence) / (1 - sample rate) before the costs are summed.

--group names a column (part_id, document id) when the decision is taken per
group, not per row: a group is positive if any row is, and its score is the
maximum of its rows (reject the part if any image is flagged).

Usage: threshold.py scores.csv [--miss-cost 10] [--reject-cost 1]
                              [--at 0.42] [--min-recall 0.95]
                              [--prevalence 0.005] [--group part_id]
Prints
  vision-threshold: N images (P positive, Q negative), AUROC x.xxx,
    threshold t at cost c: recall r, precision p, FN a, FP b
  vision-threshold at rate x: cost per 1000 model m, pass all a, reject all b;
    recall 95% interval lo to hi on P positives
and exits 1 when zero rows were read, only one class is present, or
--min-recall is given and the recall at the threshold is below it. When the
model's cost is not below the cheaper of pass all and reject all, the second
line says so: the model does not pay for itself at that rate.
"""

import argparse
import csv
import math
import sys


def auroc(rows):
    """Probability a random positive outscores a random negative (ties count half)."""
    ordered = sorted(rows, key=lambda r: r[1])
    rank_sum, i = 0.0, 0
    while i < len(ordered):
        j = i
        while j < len(ordered) and ordered[j][1] == ordered[i][1]:
            j += 1
        avg_rank = (i + 1 + j) / 2
        rank_sum += avg_rank * sum(1 for r in ordered[i:j] if r[0] == 1)
        i = j
    pos = sum(1 for r in rows if r[0] == 1)
    neg = len(rows) - pos
    return (rank_sum - pos * (pos + 1) / 2) / (pos * neg)


def confusion(rows, t):
    tp = sum(1 for lab, s in rows if lab == 1 and s >= t)
    fp = sum(1 for lab, s in rows if lab == 0 and s >= t)
    fn = sum(1 for lab, s in rows if lab == 1 and s < t)
    return tp, fp, fn


def wilson(k, n, z=1.96):
    """95% Wilson interval for k successes in n trials."""
    if n == 0:
        return 0.0, 1.0
    p = k / n
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return max(0.0, centre - half), min(1.0, centre + half)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("scores")
    ap.add_argument("--miss-cost", type=float, default=10.0)
    ap.add_argument("--reject-cost", type=float, default=1.0)
    ap.add_argument(
        "--at", type=float, help="report at this threshold instead of choosing one"
    )
    ap.add_argument("--min-recall", type=float)
    ap.add_argument(
        "--prevalence",
        type=float,
        help="positive rate where the model runs, when the evaluation set's rate differs",
    )
    ap.add_argument(
        "--group", help="column to decide on: any positive row and the maximum score"
    )
    args = ap.parse_args()

    rows, groups = [], {}
    with open(args.scores, newline="", encoding="utf-8") as fh:
        for rec in csv.DictReader(fh):
            lab, score = int(float(rec["label"])), float(rec["score"])
            if args.group:
                key = rec[args.group]
                old = groups.get(key, (0, float("-inf")))
                groups[key] = (max(old[0], lab), max(old[1], score))
            else:
                rows.append((lab, score))
    if args.group:
        rows = list(groups.values())

    unit = f"{args.group} groups" if args.group else "images"
    pos = sum(1 for r in rows if r[0] == 1)
    neg = len(rows) - pos
    if not rows or not pos or not neg:
        print(
            f"vision-threshold: {len(rows)} {unit} ({pos} positive, {neg} negative); need both classes"
        )
        return 1

    rate = pos / len(rows)
    target = rate if args.prevalence is None else args.prevalence
    w_pos, w_neg = target / rate, (1 - target) / (1 - rate)

    def cost_of(fn, fp):
        return args.miss_cost * w_pos * fn + args.reject_cost * w_neg * fp

    if args.at is not None:
        best = args.at
    else:
        best, best_cost = None, None
        for t in sorted({s for _, s in rows}, reverse=True):
            _, fp, fn = confusion(rows, t)
            cost = cost_of(fn, fp)
            if best_cost is None or cost <= best_cost:
                best, best_cost = t, cost
    tp, fp, fn = confusion(rows, best)
    cost = cost_of(fn, fp)
    recall = tp / pos
    precision = tp / (tp + fp) if tp + fp else 0.0
    print(
        f"vision-threshold: {len(rows)} {unit} ({pos} positive, {neg} negative), AUROC {auroc(rows):.3f}, "
        f"threshold {best:.4g} at cost {cost:.1f}: recall {recall:.3f}, precision {precision:.3f}, FN {fn}, FP {fp}"
    )
    per = 1000 / len(rows)
    model = cost * per
    pass_all = args.miss_cost * w_pos * pos * per
    reject_all = args.reject_cost * w_neg * neg * per
    lo, hi = wilson(tp, pos)
    verdict = "" if model < min(pass_all, reject_all) else "; the model does not pay for itself at this rate"
    print(
        f"vision-threshold at rate {target:.4g}: cost per 1000 model {model:.1f}, pass all {pass_all:.1f}, "
        f"reject all {reject_all:.1f}; recall 95% interval {lo:.2f} to {hi:.2f} on {pos} positives{verdict}"
    )
    if args.min_recall is not None and recall < args.min_recall:
        print(f"recall {recall:.3f} is below the gate {args.min_recall:.3f}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
