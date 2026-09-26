#!/usr/bin/env python3
"""wer: word and character error rate for a speech feature, computed from a
reference and a hypothesis per utterance, so a WER in speech's report
is measured, not claimed.

Input is JSONL, one object per utterance:
  {"id": "call-01-t3", "lang": "hi", "ref": "...", "hyp": "..."}
`lang` is optional (reported as "und"). Both texts go through the same
normaliser before scoring: Unicode NFC, lowercase, the danda and double
danda (U+0964, U+0965) and ASCII and Unicode punctuation removed, digits
kept, whitespace collapsed. --keep-punct turns the punctuation step off.

Scores are corpus-level: total edits over total reference words (WER) and
reference characters without spaces (CER), overall and per language.
Per-utterance lines are printed for the --worst N highest-WER utterances.

Usage: wer.py cases.jsonl [--worst 5] [--max-wer 0.20] [--keep-punct]
Prints
  speech-eval: N utterances, W reference words, WER x.xxx, CER y.yyy
and one "lang <code>:" line per language, and exits 1 when zero
utterances were read, an utterance has an empty reference, or --max-wer
is given and the overall WER is above it.
"""

import argparse
import json
import sys
import unicodedata

DANDA = {"।", "॥"}


def normalise(text, keep_punct=False):
    text = unicodedata.normalize("NFC", text).lower()
    out = []
    for ch in text:
        if not keep_punct and (ch in DANDA or unicodedata.category(ch).startswith("P")):
            out.append(" ")
        else:
            out.append(ch)
    return " ".join("".join(out).split())


def edits(ref, hyp):
    """Levenshtein distance between two sequences."""
    prev = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        cur = [i]
        for j, h in enumerate(hyp, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r != h)))
        prev = cur
    return prev[-1]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("cases")
    ap.add_argument("--worst", type=int, default=5)
    ap.add_argument("--max-wer", type=float)
    ap.add_argument("--keep-punct", action="store_true")
    args = ap.parse_args()

    rows, bad = [], 0
    with open(args.cases, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if not line.strip():
                continue
            case = json.loads(line)
            ref = normalise(case.get("ref", ""), args.keep_punct)
            hyp = normalise(case.get("hyp", ""), args.keep_punct)
            if not ref:
                print(f"empty reference: line {n} ({case.get('id', '?')})")
                bad += 1
                continue
            rw, hw = ref.split(), hyp.split()
            rc, hc = ref.replace(" ", ""), hyp.replace(" ", "")
            rows.append(
                (
                    case.get("id", f"line-{n}"),
                    case.get("lang", "und"),
                    edits(rw, hw),
                    len(rw),
                    edits(rc, hc),
                    len(rc),
                )
            )

    if not rows:
        print("speech-eval: 0 utterances, 0 reference words, WER n/a, CER n/a")
        return 1

    def score(subset):
        we, wn = sum(r[2] for r in subset), sum(r[3] for r in subset)
        ce, cn = sum(r[4] for r in subset), sum(r[5] for r in subset)
        return we / wn, ce / cn, wn

    wer, cer, words = score(rows)
    print(
        f"speech-eval: {len(rows)} utterances, {words} reference words, WER {wer:.3f}, CER {cer:.3f}"
    )
    for lang in sorted({r[1] for r in rows}):
        sub = [r for r in rows if r[1] == lang]
        lw, lc, _ = score(sub)
        print(f"lang {lang}: {len(sub)} utterances, WER {lw:.3f}, CER {lc:.3f}")
    for r in sorted(rows, key=lambda r: r[2] / r[3], reverse=True)[: args.worst]:
        print(f"worst {r[0]} ({r[1]}): WER {r[2] / r[3]:.3f}")

    if bad:
        return 1
    if args.max_wer is not None and wer > args.max_wer:
        print(f"WER {wer:.3f} is above the gate {args.max_wer:.3f}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
