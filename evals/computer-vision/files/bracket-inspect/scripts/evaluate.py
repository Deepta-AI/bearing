"""Contractor's evaluation: accuracy of the defect model on the test split."""

import csv

THRESHOLD = 0.5

rows = [r for r in csv.DictReader(open("data/scores.csv")) if r["split"] == "test"]
correct = sum((float(r["score"]) >= THRESHOLD) == (r["label"] == "1") for r in rows)
print(f"test images: {len(rows)}")
print(f"accuracy at {THRESHOLD}: {correct / len(rows):.1%}")
