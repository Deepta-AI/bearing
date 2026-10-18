# Datasheet: <name> (<eval | train | preference>)

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The datasheet
     travels with datasets/<name>/rows.jsonl so whoever trains on it, grades
     with it or deletes it knows where every row came from. Every section is
     filled: "none" is an allowed answer, blank is not. -->

Status: generated | filtered | audited | promoted | retired
Owner: <person>. Rows: datasets/<name>/rows.jsonl. Date: <YYYY-MM-DD>

## Provenance

<!-- What: why the set exists, which feature and eval it serves, the kind,
     and who ran the generation.
     Good: names the gap that made real data short (cells the logs never
     reach, a new language, too few rows) and the consumer that reads it.
     Example: "Eval rows for the intake classifier: 40 real notes cover 3 of
     12 cells; code-mixed and adversarial cells had none." -->

## Seed and licence

<!-- What: the seed file and row count by source, where the seed came from,
     the consent or licence that covers it, and how PII was removed.
     Good: at least 10 real rows; the licence or consent named, with the
     date it was checked; the PII function named.
     Example: "40 rows from evals/intake/cases.jsonl (real 34, owner 6);
     support logs under the 2026 data-use consent; PII removed by
     scrub_contact()." -->

## Generation

<!-- What: the taxonomy (dimensions and values, cells), the generator model
     id from the responses, the prompt name and every version used, the
     target per cell, rows generated and the cost.
     Good: model ids as the responses reported them; for eval rows a
     generator that is not the model under test; for train a teacher whose
     eval score is cited.
     Example: "taxonomy 3 dimensions, 12 cells; claude-opus-5-5 via route
     dataset-intake, prompt intake-generate v1 and v2; 600 generated,
     $4.10." -->

## Filtering

<!-- What: the dataset_check.py count line before and after filtering,
     verbatim, and the rows dropped per reason (exact duplicate, near
     duplicate at 0.8, contaminated against which golden set, schema).
     Good: both count lines copied, not retyped; empty cells named.
     Example: "dataset-check: 600 rows (real 0, owner 0, synthetic 600),
     cells 12 of 12 filled (0 empty), ... contaminated 3 against 40 cases";
     dropped 41 near duplicates, 3 contaminated." -->

## Audit

<!-- What: the sample size and how it was drawn, the auditor, accepted and
     rejected counts, acceptance percent, and the reasons behind rejects.
     Good: the auditor is a named person; the count meets the gate's
     required number; the batch that failed (if any) is recorded too.
     Example: "60 of 556 rows, stratified by cell, seed 7; audited by
     r.teja; 56 accepted (93.3%); rejects: 3 wrong labels, 1 unrealistic." -->

## PII

<!-- What: whether any row can contain personal data, how generation
     avoided copying it from the seed, and how that was checked.
     Good: a check that ran (a scan or the audit question), not a belief.
     Example: "Generated names and numbers are fictional; the PII scan
     over rows.jsonl found 0 hits." -->

## Intended use

<!-- What: what the rows may be used for, what they must not be used for,
     and where they went (promoted count, training run).
     Good: says whether rows may train a model and whether they are in a
     golden set, so no row ends up in both.
     Example: "Eval only: 300 rows promoted to evals/intake/cases.jsonl
     (synthetic 300 of 640); never training data." -->
