---
name: computer-vision
description: 'Builds computer vision features (VLM, classifier, detector, anomaly, document extraction) with leak-free splits and a cost-set threshold. Use when asked to "classify images", "detect defects" or "extract from scans".'
argument-hint: "<vlm|classify|detect|segment|anomaly|document> <name> [--images <path>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(wc -l:*), Bash(make:*), Bash(git status:*), Bash(uv run:*), Bash(nvidia-smi:*), Bash(python3 *skills/computer-vision/scripts/threshold.py*)
---

# computer-vision

A vision feature is judged by what it costs when it is wrong: a missed
defect shipped, a good part scrapped, a wrong field on a certificate.
This skill picks the cheapest approach that meets the bar, splits the
images so the score is honest, sets the operating threshold from those
costs, and measures latency where the images arrive.

Not this: training runs on Hugging Face Jobs are `huggingface-vision-trainer`
and dataset curation and error browsing in FiftyOne are
`fiftyone-dataset-curation` and `fiftyone-model-evaluation` (official
marketplace); this skill decides, measures and ships around them.

## Inputs

- Approach and name: `$1` and `$2`; if absent, asks what the feature
  must decide per image and at what volume, in one question, and
  proposes the approach in step 1.
- Images: `--images`, else `data/<name>/`; if none, step 2 writes the
  collection plan and stops the build with the counts at zero.
- Costs: the solution doc `docs/genai/<name>-solution.md` (cost of a
  miss, cost of a false reject, latency budget); if absent, asks for the
  two costs as a ratio and uses 10 to 1 marked `assumed`.
- Gateway: `llm/` from `llm-gateway` for VLM calls; if absent, one
  function wraps the call and the gateway is a follow-up.
- Approach reference: `references/approaches.md` in this skill.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
vision approach and llm provider and models. `tech-decision` asks only
about keys no accepted ADR, the request or the code already settles,
one question at a time, and records only what the user decides.

1. Approach from `$1` checked against `references/approaches.md`: a VLM
   for open-ended labels at low volume, a trained model for fixed
   classes at volume or under 100 ms, an anomaly detector when defects
   are rare and varied, a document pipeline for scans. If a cheaper
   approach fits the stated volume and latency, say so first.
2. Data. Count images per class and per source (line, camera, shift,
   supplier, document type). Split into train, validation and test by
   group, never by image: every image of one part, batch, patient or
   document stays in one split. Anomaly detection trains on good images
   only; defects appear in validation and test alone. Labelling guide in
   `docs/genai/labelling-<name>.md`. Print counts per split and class.
   When the split or the scores came from someone else, count the groups
   shared by every pair of splits (train and val, train and test, val and
   test), score the shared and unshared subsets separately, and report
   only on groups the model and the threshold never saw. Write down the
   class rate and the source mix of the labelled set next to the rate
   and mix where the model will run: curated sets are rarely a sample.
3. Baseline first: the simplest approach from step 1's list (a VLM with
   a fixed prompt, or a pretrained backbone with a linear head) scored
   on validation. That is the number to beat.
4. Build:
   - vlm: prompt with the label set and two or three reference images,
     structured output, through the gateway, confidence from the model's
     own schema field plus agreement across two calls on doubtful cases;
   - classify, detect, segment: fine-tune a pretrained model (timm or
     DINOv2 features for classification, an RT-DETR or YOLO family model
     for detection), augmentation that matches the camera, seeds fixed;
   - anomaly: patch features from a frozen pretrained backbone with a
     memory bank (PatchCore style), anomaly map per image, image score =
     the map's maximum;
   - document: OCR or a VLM for text, layout for fields, each field with
     its crop so a reviewer can check it, and format checks per source
     (a supplier's number pattern, its date order) that send a field to
     review whatever the confidence;
   - vlm and document: a call that fails or a reply that cannot be parsed
     sends the item to review with the reason, never drops it or writes
     part of it, and a test covers that path.
5. Evaluate on validation with the task's metric: macro F1 and a
   confusion matrix, mAP at the stated IoU, AUROC with the anomaly maps
   spot-checked, or exact match per field and per source for documents.
   Write `evals/<name>/scores-val.csv` (`id,label,score`, plus the group
   column) and choose the threshold with
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/computer-vision/scripts/threshold.py" evals/<name>/scores-val.csv --miss-cost <m> --reject-cost <r>`.
   Add `--group <column>` when the decision is per part or document (a
   part is rejected if any image is flagged), and `--prevalence <rate>`
   when the labelled set's positive rate differs from the line's: the
   cost-optimal threshold moves with the rate. Per-source error rates are
   weighted by the production mix the same way before quoting what the
   model will do in a day. Then score the test split once at that
   threshold with `--at <t>`. The second line compares the model with
   passing everything and rejecting everything at that rate; when the
   model does not beat both, say so before any threshold. With fewer than
   about 30 positives, quote the recall interval it prints and call the
   threshold provisional.
6. Serving: export (ONNX or TorchScript) when the model is trained,
   measure p50 and p95 per image on the hardware that will serve
   (`nvidia-smi` shows the GPU, or state CPU), batch where the source
   allows. Every prediction stores model version, score and threshold.
7. Human review: predictions within a band around the threshold go to a
   review queue; reviewer decisions are stored and become the next
   labels. The band is set so the queue fits the reviewers' day.
8. Print the contract.

## Output contract

```
## Vision: <name> (<approach>)
images: train <a> / val <b> / test <c>, split by <group>, classes <k>
baseline: <metric> <x> (<approach>) on validation
model: <metric> <y> on validation; <vision-threshold line for val, verbatim>
test at threshold: <vision-threshold line with --at, verbatim>
costs: miss <m>, false reject <r> (<source | assumed>)
latency: p50 <ms>, p95 <ms> on <hardware>
review band: <low>-<high>, about <n> images a day
not run: <each model call, downstream write and measurement not exercised>
```

## Gotchas

- Run the kit's scripts from the kit path while working. When the repo
  wants a make target or CI job for a check, copy the script into the
  repo's `scripts/` and point the target there; a target that names the
  kit's own path breaks on every other machine.
- Random splits of near-identical frames give a test score that never
  happens again in production. Split by part, batch, camera or document.
- Accuracy on a 2% defect rate is 98% for a model that sees nothing.
  Report AUROC, recall at the threshold and the cost, never accuracy.
- The threshold is a business decision expressed as costs; chosen on
  validation, reported on test once. Tuning on test is leakage.
- Lighting, lens and compression shift between lab photos and the line
  camera. Collect validation images from the camera that will serve.
- A VLM's stated confidence is not calibrated. Use it for ranking and
  review routing, not as a probability; show how it ranks right against
  wrong values (the count of wrong values at high confidence, or AUROC).
- A threshold the user names is their decision. Measure what it lets
  through; if something else ships, the first line of the reply says
  what, why, and that the choice is theirs to confirm.
