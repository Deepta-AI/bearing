#!/usr/bin/env bash
# tests/unit/dataset_check.sh: dataset-generation's dataset_check.py. It
# counts rows by source, taxonomy cells filled, exact and near duplicates,
# contamination against a golden set and the person audit of synthetic rows;
# exit 1 on any problem, exit 2 when it checked nothing. Rows come in the
# shapes llm-eval and llm-fine-tuning already write: `input` a string or an
# object, chat `messages`, any `source` string.
set -u
. "$(dirname "$0")/../lib/assert.sh"
DC="$KIT/plugins/bearing-genai/skills/dataset-generation/scripts/dataset_check.py"
d="$(tmpdir)"

# Fixtures. Random word sentences keep unrelated rows far apart in 5-grams.
python3 - "$d" <<'PY'
import json, random, sys
d = sys.argv[1]
words = ("invoice refund login password charge plan monthly yearly account "
         "locked email address delivery parcel late broken screen battery "
         "warranty discount coupon expired branch office manager payroll "
         "salary slip tax form upload failed export report weekly daily "
         "printer driver laptop cable router signal outage outside hours "
         "holiday leave approval pending rejected duplicate missing wrong "
         "currency rupee dollar transfer bank cheque").split()
def sentences(seed, n):
    r = random.Random(seed)
    return [" ".join(r.choice(words) for _ in range(9)) for _ in range(n)]
def write(name, rows):
    with open(f"{d}/{name}", "w") as f:
        for row in rows:
            f.write(json.dumps(row) + "\n")
cells = [{"intent": i, "length": l} for i in ("billing", "access") for l in ("short", "long")]
golden = sentences(1, 5)
# llm-eval's case shape: object input, expected, source user-log
write("cases.jsonl", [{"id": f"c-{i}", "task": "classification", "input": {"text": t},
                       "expected": "billing_dispute", "source": "user-log"}
                      for i, t in enumerate(golden)])
json.dump({"dimensions": {"intent": ["billing", "access"], "length": ["short", "long"]}},
          open(f"{d}/tax.json", "w"))
texts = sentences(2, 12)
train = []
for i, t in enumerate(texts):
    src = ("user-log", "real", "crm-export")[i % 3]
    c = cells[i % 4]
    if i < 6:
        train.append({"id": f"t{i}", "input": t, "output": "billing", "source": src, "cell": c})
    elif i < 10:
        train.append({"id": f"t{i}", "source": src, "cell": c, "messages": [
            {"role": "system", "content": "Classify the message. Reply with the label only."},
            {"role": "user", "content": t}, {"role": "assistant", "content": "access"}]})
    else:
        train.append({"id": f"t{i}", "input": {"text": t}, "output": "billing", "source": src, "cell": c})
write("train.jsonl", train)
# a chat row equal to golden case 0 except case and spacing
leak = {"id": "leak", "source": "user-log", "messages": [
    {"role": "system", "content": "Classify the message. Reply with the label only."},
    {"role": "user", "content": "  " + golden[0].upper().replace(" ", "   ") + " "},
    {"role": "assistant", "content": "billing"}]}
write("train-leak.jsonl", train + [leak])
# a string input equal to an object case input
write("train-leak-str.jsonl", train[:3] + [{"id": "ls", "input": golden[1].title(), "output": "x", "source": "owner"}])
write("dup.jsonl", train[:3] + [dict(train[0], id="t0b")])
write("nosource.jsonl", train[:3] + [{"id": "ns", "input": "a row with no provenance at all", "output": "x"}])
write("near.jsonl", train[:3] + [dict(train[0], id="t0n", input=train[0]["input"] + " x")])
write("nooutput.jsonl", train[:3] + [{"id": "no", "input": "a train row with nothing to learn", "source": "owner"}])
write("train-3cells.jsonl", [r for r in train if r["cell"] != cells[3]])
write("offtax.jsonl", train[:3] + [dict(train[3], id="off", cell={"intent": "refunds", "length": "short"})])
syn = sentences(3, 40)
write("syn40.jsonl", [{"id": f"s{i}", "input": t, "expected": "billing", "source": "synthetic",
                       "cell": cells[i % 4]} for i, t in enumerate(syn)])
def audit(name, acc, rej):
    rows = [{"id": f"s{i}", "verdict": "accept", "by": "a.person"} for i in range(acc)]
    rows += [{"id": f"s{acc + i}", "verdict": "reject", "by": "a.person"} for i in range(rej)]
    write(name, rows)
audit("audit20.jsonl", 20, 0)
audit("audit30ok.jsonl", 28, 2)
audit("audit30bad.jsonl", 24, 6)
write("audit-noby.jsonl", [{"id": f"s{i}", "verdict": "accept"} for i in range(30)])
big = sentences(4, 70)
write("cases60.jsonl", [{"id": f"g{i}", "input": {"text": t}, "expected": "x", "source": "user-log"} for i, t in enumerate(big[:60])])
write("cases10.jsonl", [{"id": f"g{i}", "input": {"text": t}, "expected": "x", "source": "user-log"} for i, t in enumerate(big[60:])])
# an eval row that repeats a golden case adds nothing
write("eval-repeat.jsonl", [{"id": "e0", "input": {"text": big[0]}, "expected": "x", "source": "owner"}])
write("pref.jsonl", [{"id": f"p{i}", "source": "owner",
                      "prompt": [{"role": "user", "content": t}],
                      "chosen": [{"role": "assistant", "content": "good"}],
                      "rejected": [{"role": "assistant", "content": "bad"}]} for i, t in enumerate(sentences(5, 4))])
# Task 6 fix round 1 fixtures
blocks = {"id": "cb", "source": "user-log", "messages": [
    {"role": "user", "content": [{"type": "text", "text": "My invoice for March shows two charges for the same plan."}]},
    {"role": "assistant", "content": "billing_dispute"}]}
write("blocks.jsonl", train[:3] + [blocks])
write("question.jsonl", train[:3] + [{"id": "q", "input": "Summarise the cancellation terms for a monthly plan.", "output": "x", "source": "owner"}])
write("wrapped.jsonl", train[:3] + [{"id": "w", "input": "Classify this support message and reply with one label only: My invoice for March shows two charges for the same plan. Thanks in advance", "output": "x", "source": "owner"}])
write("teacher.jsonl", [dict(r, source=s) for r, s in zip(train[:4], ("teacher:claude-opus-5-5", "claude-sonnet-5-5:v2", "teacher", "user-log"))])
syn200 = sentences(6, 200)
write("syn200.jsonl", [{"id": f"y{i}", "input": t, "expected": "x", "output": "x", "source": "synthetic"} for i, t in enumerate(syn200)])
# Task 6 fix round 2 fixtures: model ids with no separator after the family,
# real sources that only resemble a family, and a case hidden by format characters
write("modelid.jsonl", [dict(r, source=s) for r, s in zip(train[:4], ("llama3:8b", "gpt4o", "qwen2.5:7b", "user-log"))])
# vendor and platform prefixes (M1): the model after the last / or a
# vendor. prefix decides; a platform head such as vllm: counts as synthetic
write("vendor.jsonl", [dict(r, source=s) for r, s in zip(train[:10], (
    "anthropic/claude-sonnet-5-5", "meta-llama/Llama-3.1-8B-Instruct", "Qwen/Qwen2.5-7B-Instruct",
    "anthropic.claude-haiku-4-5", "us.anthropic.claude-opus-5-5", "vllm:support-classifier-v1",
    "openrouter:x", "Command-R+", "user-log", "crm/export"))])
write("lookalike.jsonl", [dict(r, source=s) for r, s in zip(train[:5], ("commander", "o365", "gptzero", "phish-reports", "claudette"))])
zw = golden[2].replace(" ", " \u200b").replace("a", "a\u200d", 1)
write("zerowidth.jsonl", train[:3] + [{"id": "zw", "input": "\ufeff" + zw, "output": "x", "source": "owner"}])
with open(f"{d}/big.jsonl", "w") as f:
    for i in range(20001):
        f.write(json.dumps({"id": f"b{i}", "input": f"row number {i}", "output": "x", "source": "user-log"}) + "\n")
PY

t_begin "clean train set passes with every count printed"
assert_exit 0 python3 "$DC" "$d/train.jsonl" --kind train --against "$d/cases.jsonl" --taxonomy "$d/tax.json"
assert_contains "$T_OUT" "dataset-check: 12 rows (real 12, owner 0, synthetic 0), cells 4 of 4 filled (0 empty), exact duplicates 0"
assert_contains "$T_OUT" "near duplicates 0, contaminated 0 against 5 cases, audited 0 of 0 required"
assert_contains "$T_OUT" "dataset-check: passed"
t_end

t_begin "contamination survives normalisation"
# a train row equal to a golden case except case and spacing
assert_exit 1 python3 "$DC" "$d/train-leak.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "contaminated 1 against"
assert_contains "$T_OUT" "leak: contaminated"
t_end

t_begin "a string input matches an object case input (R11)"
assert_exit 1 python3 "$DC" "$d/train-leak-str.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "contaminated 1 against 5 cases"
assert_contains "$T_OUT" "(real 3, owner 1, synthetic 0)"
t_end

t_begin "an eval row that repeats a golden case fails"
assert_exit 1 python3 "$DC" "$d/eval-repeat.jsonl" --kind eval --against "$d/cases60.jsonl"
assert_contains "$T_OUT" "contaminated 1 against 60 cases"
t_end

t_begin "exact duplicate and missing source each fail"
assert_exit 1 python3 "$DC" "$d/dup.jsonl" --kind train; assert_contains "$T_OUT" "exact duplicates 1"
assert_exit 1 python3 "$DC" "$d/nosource.jsonl" --kind train; assert_contains "$T_OUT" "missing source"
t_end

t_begin "a near duplicate is counted and fails over --max-near"
assert_exit 1 python3 "$DC" "$d/near.jsonl" --kind train
assert_contains "$T_OUT" "exact duplicates 0, near duplicates 1"
assert_exit 0 python3 "$DC" "$d/near.jsonl" --kind train --max-near 0.5 --against "$d/cases.jsonl"
t_end

t_begin "a train row with no output or assistant turn fails"
assert_exit 1 python3 "$DC" "$d/nooutput.jsonl" --kind train; assert_contains "$T_OUT" "no: no output"
t_end

t_begin "chat preference rows read prompt, chosen and rejected"
assert_exit 0 python3 "$DC" "$d/pref.jsonl" --kind preference --against "$d/cases.jsonl"
assert_contains "$T_OUT" "dataset-check: 4 rows (real 0, owner 4, synthetic 0)"
assert_exit 1 python3 "$DC" "$d/train.jsonl" --kind preference; assert_contains "$T_OUT" "no chosen"
t_end

t_begin "synthetic eval rows need an audit of at least 30 and 90% accepted"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit20.jsonl"; assert_contains "$T_OUT" "audited 20 of 30 required"
assert_exit 0 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30ok.jsonl" --against "$d/cases60.jsonl"
assert_contains "$T_OUT" "audited 30 of 30 required (accepted 93.3%)"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30bad.jsonl" --against "$d/cases60.jsonl"; assert_contains "$T_OUT" "accepted 80.0%"
t_end

t_begin "an audit row without a person does not count"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit-noby.jsonl" --against "$d/cases60.jsonl"
assert_contains "$T_OUT" "audited 0 of 30 required"
t_end

t_begin "synthetic share over half of an eval set fails"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30ok.jsonl" --against "$d/cases10.jsonl"; assert_contains "$T_OUT" "synthetic share"
t_end

t_begin "empty cells are counted"
assert_exit 0 python3 "$DC" "$d/train-3cells.jsonl" --kind train --taxonomy "$d/tax.json" --against "$d/cases.jsonl"; assert_contains "$T_OUT" "cells 3 of 4 filled (1 empty)"
t_end

t_begin "a cell outside the taxonomy fails"
assert_exit 1 python3 "$DC" "$d/offtax.jsonl" --kind train --taxonomy "$d/tax.json"; assert_contains "$T_OUT" "off: cell outside the taxonomy"
t_end

t_begin "above 20000 rows near duplicates are skipped and said so"
assert_exit 0 python3 "$DC" "$d/big.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "dataset-check: 20001 rows"
assert_contains "$T_OUT" "near duplicates: skipped above 20000 rows"
t_end

t_begin "zero rows exits 2"
: > "$d/none.jsonl"; assert_exit 2 python3 "$DC" "$d/none.jsonl" --kind train; assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "an empty --against file is a problem, not a pass"
assert_exit 1 python3 "$DC" "$d/train.jsonl" --kind train --against "$d/none.jsonl"; assert_contains "$T_OUT" "0 cases"
t_end

TC="$KIT/plugins/bearing-genai/skills/llm-eval/templates/cases.jsonl"
FT="$KIT/plugins/bearing-genai/skills/llm-fine-tuning/templates"

t_begin "chat content blocks are flattened and match an object case"
assert_exit 1 python3 "$DC" "$d/blocks.jsonl" --kind train --against "$TC"
assert_contains "$T_OUT" "cb: contaminated"
t_end

t_begin "a row repeating one string value of a case is contaminated"
assert_exit 1 python3 "$DC" "$d/question.jsonl" --kind train --against "$TC"
assert_contains "$T_OUT" "q: contaminated"
t_end

t_begin "a row that wraps a case text is contaminated by containment"
assert_exit 1 python3 "$DC" "$d/wrapped.jsonl" --kind train --against "$TC"
assert_contains "$T_OUT" "w: contaminated"
t_end

t_begin "teacher and model-prefixed sources count as synthetic"
assert_exit 1 python3 "$DC" "$d/teacher.jsonl" --kind train
assert_contains "$T_OUT" "4 rows (real 1, owner 0, synthetic 3)"
t_end

t_begin "eval kind audits 20 percent, other kinds 10 percent or 30"
assert_exit 1 python3 "$DC" "$d/syn200.jsonl" --kind eval; assert_contains "$T_OUT" "audited 0 of 40 required"
assert_exit 1 python3 "$DC" "$d/syn200.jsonl" --kind train; assert_contains "$T_OUT" "audited 0 of 30 required"
t_end

t_begin "the fine-tuning templates do not copy the llm-eval cases"
# the teacher row still needs its audit, so only contamination is asserted
t_run python3 "$DC" "$FT/dataset.jsonl" --kind train --against "$TC"
assert_contains "$T_OUT" "3 rows (real 1, owner 1, synthetic 1)"
assert_contains "$T_OUT" "contaminated 0 against 4 cases"
assert_exit 0 python3 "$DC" "$FT/preference.jsonl" --kind preference --against "$TC"
assert_contains "$T_OUT" "contaminated 0 against 4 cases"
t_end

t_begin "a missing rows, against, audit or taxonomy file prints 0 rows and exits 2"
assert_exit 2 python3 "$DC" "$d/absent.jsonl" --kind train; assert_contains "$T_OUT" "0 rows"
assert_exit 2 python3 "$DC" "$d/train.jsonl" --kind train --against "$d/absent.jsonl"; assert_contains "$T_OUT" "0 rows"
assert_exit 2 python3 "$DC" "$d/train.jsonl" --kind train --audit "$d/absent.jsonl"; assert_contains "$T_OUT" "0 rows"
assert_exit 2 python3 "$DC" "$d/train.jsonl" --kind train --taxonomy "$d/absent.json"; assert_contains "$T_OUT" "0 rows"
assert_not_contains "$T_OUT" "  cell "
t_end

t_begin "model ids with no separator after the family count as synthetic"
assert_exit 1 python3 "$DC" "$d/modelid.jsonl" --kind train
assert_contains "$T_OUT" "4 rows (real 1, owner 0, synthetic 3)"
t_end

t_begin "real sources that only resemble a model family stay real"
assert_exit 0 python3 "$DC" "$d/lookalike.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "5 rows (real 5, owner 0, synthetic 0)"
t_end

t_begin "zero-width and format characters do not hide a case"
assert_exit 1 python3 "$DC" "$d/zerowidth.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "zw: contaminated"
t_end

t_begin "train and preference without --against fail: 0 cases checked; eval does not need it (I6)"
assert_exit 1 python3 "$DC" "$d/train.jsonl" --kind train
assert_contains "$T_OUT" "contamination: 0 cases checked"
assert_contains "$T_OUT" "contaminated 0 against 0 cases"
assert_exit 1 python3 "$DC" "$d/pref.jsonl" --kind preference
assert_contains "$T_OUT" "contamination: 0 cases checked"
assert_exit 0 python3 "$DC" "$d/eval-repeat.jsonl" --kind eval
assert_contains "$T_OUT" "dataset-check: passed"
t_end

t_begin "vendor and platform prefixes count as synthetic (M1)"
assert_exit 1 python3 "$DC" "$d/vendor.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "10 rows (real 2, owner 0, synthetic 8)"
t_end

t_begin "llm-fine-tuning step 3's command passes on its shipped templates, audit included (I3)"
assert_exit 0 python3 "$DC" "$FT/dataset.jsonl" --kind train --against "$TC" --audit "$FT/audit.jsonl"
assert_contains "$T_OUT" "audited 1 of 1 required"
assert_contains "$T_OUT" "dataset-check: passed"
t="$(tr '\n' ' ' < "$KIT/plugins/bearing-genai/skills/llm-fine-tuning/SKILL.md" | tr -s ' ')"
assert_contains "$t" "--against evals/<name>/cases.jsonl --audit data/<name>/audit.jsonl"
t_end

t_summary
