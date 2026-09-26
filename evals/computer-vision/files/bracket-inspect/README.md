# bracket-inspect

Visual inspection for stamped steel mounting brackets at the press shop.
Each bracket is photographed by up to four cameras at the end of line L1 or
L2; a model scores every image for surface defects (cracks, burrs, dents).
A bracket is rejected if any of its images is flagged.

The model was trained by an outside contractor. We have its scores for every
labelled image in `data/scores.csv`:

| column | meaning |
| --- | --- |
| image_id | one photo |
| part_id | the bracket in the photo (serial laser-etched on the part) |
| line, camera | where it was taken |
| split | train, val or test, as the contractor assigned them |
| label | 1 = defect confirmed by quality, 0 = good |
| score | model output, higher = more likely defective |

The contractor's evaluation is `scripts/evaluate.py`, and its result is in
`reports/eval_report.md`.

The labelled set is not a sample of the line. Quality added every bracket it
rejected over the last six months, so defects are far more common in
`data/scores.csv` than on the press: on the line about 1 bracket in 200 is
defective (quality's figure for the last quarter).

The training code and images stay with the contractor; this repository only
has the scores.
