#!/usr/bin/env bash
# tests/unit/ai_depth_scripts.sh: the measuring scripts of speech (wer.py,
# latency_report.py), computer-vision (threshold.py), tabular-ml (split_check.py,
# baseline_gate.py), llm-fine-tuning (gpu_check.py) and llm-gateway
# (llm_access_check.py). Each computes the number its skill reports, and
# each fails on empty input and prints the count of what it checked.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SK="$KIT/plugins/bearing/skills"

# --- wer.py ---------------------------------------------------------------
t_begin "wer: exact match scores zero; the normaliser ignores case, punctuation and the danda"
d="$(tmpdir)"
cat > "$d/c.jsonl" <<'J'
{"id": "a", "lang": "en", "ref": "Book me for Tuesday, please.", "hyp": "book me for tuesday please"}
{"id": "b", "lang": "hi", "ref": "कल सुबह आइए।", "hyp": "कल सुबह आइए"}
J
assert_exit 0 python3 "$SK/speech/scripts/wer.py" "$d/c.jsonl"
assert_contains "$T_OUT" "speech-eval: 2 utterances, 8 reference words, WER 0.000, CER 0.000"
assert_contains "$T_OUT" "lang hi: 1 utterances, WER 0.000"
t_end

t_begin "wer: one substitution in four words is 0.25, and the gate fails above it"
d="$(tmpdir)"
printf '{"id":"x","lang":"en","ref":"call me at nine","hyp":"call me at five"}\n' > "$d/c.jsonl"
assert_exit 0 python3 "$SK/speech/scripts/wer.py" "$d/c.jsonl"
assert_contains "$T_OUT" "WER 0.250"
assert_exit 1 python3 "$SK/speech/scripts/wer.py" "$d/c.jsonl" --max-wer 0.2
assert_contains "$T_OUT" "above the gate"
t_end

t_begin "wer: empty file and an empty reference both fail"
d="$(tmpdir)"; : > "$d/e.jsonl"
assert_exit 1 python3 "$SK/speech/scripts/wer.py" "$d/e.jsonl"
assert_contains "$T_OUT" "speech-eval: 0 utterances"
printf '{"id":"a","ref":"hello","hyp":"hello"}\n{"id":"b","ref":"  ","hyp":"x"}\n' > "$d/r.jsonl"
assert_exit 1 python3 "$SK/speech/scripts/wer.py" "$d/r.jsonl"
assert_contains "$T_OUT" "empty reference: line 2 (b)"
t_end

# --- latency_report.py ----------------------------------------------------
t_begin "latency: turns inside the budget pass with p95 per stage"
d="$(tmpdir)"
: > "$d/t.jsonl"
for i in 1 2 3 4 5; do printf '{"turn":"t%s","speech_end":0,"asr_final":200,"llm_first_token":700,"tts_first_audio":950}\n' "$i" >> "$d/t.jsonl"; done
assert_exit 0 python3 "$SK/speech/scripts/latency_report.py" "$d/t.jsonl"
assert_contains "$T_OUT" "voice-latency: 5 turns, 0 broken, total p95 950 ms (budget 1500), 0 stages over budget"
assert_contains "$T_OUT" "llm: p50 500 ms, p95 500 ms, budget 700 ms, ok"
t_end

t_begin "latency: a slow model stage and a broken turn both fail"
d="$(tmpdir)"
printf '{"turn":"a","speech_end":0,"asr_final":200,"llm_first_token":1400,"tts_first_audio":1600}\n' > "$d/t.jsonl"
assert_exit 1 python3 "$SK/speech/scripts/latency_report.py" "$d/t.jsonl"
assert_contains "$T_OUT" "llm: p50 1200 ms, p95 1200 ms, budget 700 ms, OVER"
printf '{"turn":"b","speech_end":0,"asr_final":300,"llm_first_token":100,"tts_first_audio":500}\n' >> "$d/t.jsonl"
assert_exit 1 python3 "$SK/speech/scripts/latency_report.py" "$d/t.jsonl" --budget llm=1500,total=2000
assert_contains "$T_OUT" "broken turn: b"
: > "$d/e.jsonl"
assert_exit 1 python3 "$SK/speech/scripts/latency_report.py" "$d/e.jsonl"
assert_contains "$T_OUT" "voice-latency: 0 turns"
t_end

# --- threshold.py ---------------------------------------------------------
t_begin "threshold: a perfect separator has AUROC 1 and the cost-optimal cut catches every defect"
d="$(tmpdir)"
printf 'id,label,score\na,0,0.1\nb,0,0.2\nc,0,0.3\nd,1,0.8\ne,1,0.9\n' > "$d/s.csv"
assert_exit 0 python3 "$SK/computer-vision/scripts/threshold.py" "$d/s.csv"
assert_contains "$T_OUT" "vision-threshold: 5 images (2 positive, 3 negative), AUROC 1.000, threshold 0.8 at cost 0.0: recall 1.000, precision 1.000, FN 0, FP 0"
t_end

t_begin "threshold: an expensive miss pulls the threshold down; --min-recall gates a fixed cut"
d="$(tmpdir)"
printf 'id,label,score\na,0,0.1\nb,0,0.6\nc,1,0.5\nd,1,0.9\n' > "$d/s.csv"
assert_exit 0 python3 "$SK/computer-vision/scripts/threshold.py" "$d/s.csv" --miss-cost 10 --reject-cost 1
assert_contains "$T_OUT" "AUROC 0.750, threshold 0.5 at cost 1.0: recall 1.000"
assert_exit 1 python3 "$SK/computer-vision/scripts/threshold.py" "$d/s.csv" --at 0.7 --min-recall 0.9
assert_contains "$T_OUT" "recall 0.500"
t_end

t_begin "threshold: zero rows or one class fails"
d="$(tmpdir)"; printf 'id,label,score\n' > "$d/e.csv"
assert_exit 1 python3 "$SK/computer-vision/scripts/threshold.py" "$d/e.csv"
assert_contains "$T_OUT" "0 images (0 positive, 0 negative); need both classes"
printf 'id,label,score\na,0,0.1\nb,0,0.4\n' > "$d/one.csv"
assert_exit 1 python3 "$SK/computer-vision/scripts/threshold.py" "$d/one.csv"
t_end

# --- split_check.py -------------------------------------------------------
t_begin "split: an ordered time split with disjoint users passes"
d="$(tmpdir)"
printf 'user,ts,churn\nu1,2026-01-05,0\nu2,2026-01-20,1\n' > "$d/tr.csv"
printf 'user,ts,churn\nu3,2026-02-03,1\nu4,2026-02-10,0\n' > "$d/te.csv"
assert_exit 0 python3 "$SK/tabular-ml/scripts/split_check.py" --train "$d/tr.csv" --test "$d/te.csv" --time ts --group user --target churn
assert_contains "$T_OUT" "ml-split: train 2, valid 0, test 2 rows; time ok; groups overlapping 0; target ok; 0 problems"
t_end

t_begin "split: overlapping time and a shared user are leaks"
d="$(tmpdir)"
printf 'user,ts,churn\nu1,2026-01-05,0\nu2,2026-02-20,1\n' > "$d/tr.csv"
printf 'user,ts,churn\nu2,2026-02-03,1\nu4,2026-02-10,0\n' > "$d/te.csv"
assert_exit 1 python3 "$SK/tabular-ml/scripts/split_check.py" --train "$d/tr.csv" --test "$d/te.csv" --time ts --group user
assert_contains "$T_OUT" "time leak: train ends at 2026-02-20 but test starts at 2026-02-03"
assert_contains "$T_OUT" "group leak: 1 user values in more than one split, e.g. u2"
t_end

t_begin "split: an empty file, a missing column and no split column all fail"
d="$(tmpdir)"
printf 'user,ts\n' > "$d/tr.csv"; printf 'user,ts\nu1,1\n' > "$d/te.csv"
assert_exit 1 python3 "$SK/tabular-ml/scripts/split_check.py" --train "$d/tr.csv" --test "$d/te.csv" --time ts
assert_contains "$T_OUT" "empty split: train"
printf 'user,ts\nu0,0\n' > "$d/tr.csv"
assert_exit 1 python3 "$SK/tabular-ml/scripts/split_check.py" --train "$d/tr.csv" --test "$d/te.csv" --time when
assert_contains "$T_OUT" "missing column 'when' in train"
assert_exit 2 python3 "$SK/tabular-ml/scripts/split_check.py" --train "$d/tr.csv" --test "$d/te.csv"
t_end

# --- baseline_gate.py -----------------------------------------------------
t_begin "baseline gate: passes above the margin, fails inside it, handles lower-is-better"
d="$(tmpdir)"
printf '{"baseline":{"name":"recency","auc":0.66,"mae":12},"model":{"name":"lgbm","auc":0.74,"mae":9}}' > "$d/m.json"
assert_exit 0 python3 "$SK/tabular-ml/scripts/baseline_gate.py" "$d/m.json" --metric auc --min-lift 0.02
assert_contains "$T_OUT" "ml-baseline: auc baseline 0.66 (recency), model 0.74 (lgbm), lift 0.08, gate 0.02: pass"
assert_exit 1 python3 "$SK/tabular-ml/scripts/baseline_gate.py" "$d/m.json" --metric auc --min-lift 0.1
assert_exit 0 python3 "$SK/tabular-ml/scripts/baseline_gate.py" "$d/m.json" --metric mae --lower-is-better --min-lift 1
assert_exit 1 python3 "$SK/tabular-ml/scripts/baseline_gate.py" "$d/m.json" --metric f1
assert_contains "$T_OUT" "f1 missing"
t_end

# --- gpu_check.py ---------------------------------------------------------
t_begin "gpu check: a 24 GB card fits LoRA on 7B, not a full fine-tune; no GPU fails unless --allow-cpu"
d="$(tmpdir)"
printf '#!/bin/sh\necho "NVIDIA L4, 24576, 23000"\n' > "$d/smi"; chmod +x "$d/smi"
assert_exit 0 env NVIDIA_SMI="$d/smi" python3 "$SK/llm-fine-tuning/scripts/gpu_check.py" --params-b 7 --method lora
assert_contains "$T_OUT" "gpu-check: 1 GPUs, best NVIDIA L4 22.5 GB free, need ~18.8 GB for lora on 7B: fits"
assert_exit 1 env NVIDIA_SMI="$d/smi" python3 "$SK/llm-fine-tuning/scripts/gpu_check.py" --params-b 7 --method full
assert_contains "$T_OUT" "does not fit"
printf '#!/bin/sh\nexit 9\n' > "$d/none"; chmod +x "$d/none"
assert_exit 1 env NVIDIA_SMI="$d/none" python3 "$SK/llm-fine-tuning/scripts/gpu_check.py" --params-b 0.6 --method lora
assert_contains "$T_OUT" "gpu-check: 0 GPUs"
assert_exit 0 env NVIDIA_SMI="$d/none" python3 "$SK/llm-fine-tuning/scripts/gpu_check.py" --params-b 0.6 --method lora --allow-cpu
assert_contains "$T_OUT" "cpu smoke only"
t_end

# --- llm_access_check.py --------------------------------------------------
t_begin "access: every provider in routing.yaml needs its key; a vllm model needs its base_url variable"
d="$(tmpdir)"
cat > "$d/routing.yaml" <<'Y'
version: 1
models:
  claude-sonnet-5:
    provider: anthropic
    input_per_m: 2.00
  or-haiku:
    provider: openrouter   # one capped key
  support-v1:
    provider: vllm
    base_url: ${LLM_VLLM_URL}
tiers:
  fast:
    model: or-haiku
Y
assert_exit 1 env -u ANTHROPIC_API_KEY -u OPENROUTER_API_KEY -u LLM_VLLM_URL python3 "$SK/llm-gateway/scripts/llm_access_check.py" --routing "$d/routing.yaml" --env "$d/none"
assert_contains "$T_OUT" "llm-access: 3 models, 3 providers checked, 0 ready, 3 missing"
assert_contains "$T_OUT" "MISSING: vllm [support-v1]: base_url set, NOT SET: LLM_VLLM_URL"
printf 'OPENROUTER_API_KEY=sk-or-x\nLLM_VLLM_URL=http://gpu:8000/v1\n' > "$d/.env"
assert_exit 0 env -u OPENROUTER_API_KEY -u LLM_VLLM_URL ANTHROPIC_API_KEY=x python3 "$SK/llm-gateway/scripts/llm_access_check.py" --routing "$d/routing.yaml" --env "$d/.env"
assert_contains "$T_OUT" "llm-access: 3 models, 3 providers checked, 3 ready, 0 missing"
assert_not_contains "$T_OUT" "sk-or-x"
t_end

t_begin "access: a missing routing file, no models and an unknown provider fail"
d="$(tmpdir)"
assert_exit 1 python3 "$SK/llm-gateway/scripts/llm_access_check.py" --routing "$d/nope.yaml"
printf 'version: 1\nmodels:\ntiers:\n' > "$d/empty.yaml"
assert_exit 1 python3 "$SK/llm-gateway/scripts/llm_access_check.py" --routing "$d/empty.yaml" --env "$d/none"
assert_contains "$T_OUT" "llm-access: 0 models"
printf 'models:\n  m:\n    provider: magic\n' > "$d/u.yaml"
assert_exit 1 python3 "$SK/llm-gateway/scripts/llm_access_check.py" --routing "$d/u.yaml" --env "$d/none"
assert_contains "$T_OUT" "unknown provider"
t_end

t_summary
