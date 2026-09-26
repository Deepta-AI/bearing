#!/usr/bin/env python3
"""latency_report: the per-stage latency of a voice agent's turns against
the budget, so "it feels fast" becomes p50 and p95 numbers per stage.

Input is JSONL, one object per caller turn, times in milliseconds from
any common origin (the turn's own clock is fine):
  {"turn": "call-3/7", "speech_end": 0, "asr_final": 180,
   "llm_first_token": 620, "tts_first_audio": 840}
Stages are the gaps between consecutive marks:
  endpointing+asr = asr_final - speech_end
  llm            = llm_first_token - asr_final
  tts            = tts_first_audio - llm_first_token
  total          = tts_first_audio - speech_end   (what the caller hears)
A turn missing a mark, or with a mark earlier than the one before it, is
counted as broken and left out of the percentiles.

Budget defaults (ms, p95): asr 300, llm 700, tts 300, total 1500;
override with --budget asr=250,llm=600,tts=250,total=1200.

Usage: latency_report.py turns.jsonl [--budget k=v,...]
Prints one line per stage with p50, p95 and the budget, then
  voice-latency: N turns, B broken, total p95 <x> ms (budget <y>), S stages over budget
and exits 1 when zero usable turns were read, any turn is broken, or any
stage's p95 is over its budget.
"""

import argparse
import json
import sys

MARKS = ["speech_end", "asr_final", "llm_first_token", "tts_first_audio"]
STAGES = [("asr", 0, 1), ("llm", 1, 2), ("tts", 2, 3), ("total", 0, 3)]
DEFAULT = {"asr": 300, "llm": 700, "tts": 300, "total": 1500}


def pct(values, p):
    ordered = sorted(values)
    k = max(0, min(len(ordered) - 1, round(p / 100 * (len(ordered) - 1))))
    return ordered[k]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("turns")
    ap.add_argument("--budget", default="")
    args = ap.parse_args()

    budget = dict(DEFAULT)
    for item in filter(None, args.budget.split(",")):
        key, _, value = item.partition("=")
        if key not in budget:
            print(f"unknown budget stage {key!r}; expected one of {', '.join(budget)}")
            return 2
        budget[key] = float(value)

    usable, broken = [], 0
    with open(args.turns, encoding="utf-8") as fh:
        for line in fh:
            if not line.strip():
                continue
            turn = json.loads(line)
            marks = [turn.get(m) for m in MARKS]
            if any(not isinstance(m, (int, float)) for m in marks) or any(
                b < a for a, b in zip(marks, marks[1:])
            ):
                print(f"broken turn: {turn.get('turn', '?')}")
                broken += 1
                continue
            usable.append(marks)

    if not usable:
        print(f"voice-latency: 0 turns, {broken} broken, total p95 n/a")
        return 1

    over = 0
    for name, a, b in STAGES:
        gaps = [m[b] - m[a] for m in usable]
        p50, p95 = pct(gaps, 50), pct(gaps, 95)
        flag = "OVER" if p95 > budget[name] else "ok"
        over += p95 > budget[name]
        print(
            f"{name}: p50 {p50:.0f} ms, p95 {p95:.0f} ms, budget {budget[name]:.0f} ms, {flag}"
        )
    total95 = pct([m[3] - m[0] for m in usable], 95)
    print(
        f"voice-latency: {len(usable)} turns, {broken} broken, total p95 {total95:.0f} ms (budget {budget['total']:.0f}), {over} stages over budget"
    )
    return 1 if broken or over else 0


if __name__ == "__main__":
    sys.exit(main())
