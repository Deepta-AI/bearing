# Vision approaches

Pick the cheapest approach that meets the bar at the stated volume and
latency. Every row still needs the split, the metric and the threshold
from the skill.

| Approach | Use when | Data needed | Metric | Typical latency |
| --- | --- | --- | --- | --- |
| VLM through the gateway | open-ended labels, explanations, under a few thousand images a day, no training data yet | 20 to 50 labelled images to evaluate, none to train | accuracy or field exact match on a labelled set | 1 to 5 s per image |
| Classifier on a pretrained backbone | fixed classes, volume, sub-100 ms | 100 or more images per class | macro F1, confusion matrix | 5 to 30 ms on GPU |
| Detector (RT-DETR, YOLO family) | where the thing is matters, counting | a few hundred boxed images per class | mAP at IoU 0.5 and 0.5:0.95 | 10 to 50 ms on GPU |
| Segmentation (SAM family, U-Net) | area or shape matters | masks for a few hundred images | IoU or Dice per class | 20 to 100 ms on GPU |
| Anomaly detection (PatchCore style) | defects rare and varied, good parts plentiful | 30 to 300 good images; defects only to evaluate | AUROC, recall at the cost threshold, map spot checks | 20 to 80 ms on GPU |
| Document pipeline | scans, certificates, forms | 20 to 50 labelled documents per type | field-level exact match, per field | 1 to 5 s per page |

## Combining

- An anomaly detector to flag, a VLM to describe the flagged crop for
  the operator: the VLM never decides pass or fail.
- A classifier for the common classes, a VLM for the review band only.
- Documents: classify the type first, then extract with the type's
  field list; compare fields against the system of record with fuzzy
  matching for names and exact matching for numbers and dates.

## Pointers to stronger execution tools

- Training detectors, classifiers and SAM models on Hugging Face Jobs:
  `huggingface-vision-trainer` (huggingface-skills).
- Duplicate finding, curation and splits in FiftyOne:
  `fiftyone-dataset-curation`, `fiftyone-find-duplicates`.
- mAP, PR curves and browsing false positives and negatives:
  `fiftyone-model-evaluation`.
- Choosing a current model per task from leaderboards: `huggingface-best`.

Public datasets for demos and evals (check each licence before a
commercial demo): MVTec AD and VisA for industrial anomaly detection,
COCO for detection, FUNSD and SROIE for documents.
