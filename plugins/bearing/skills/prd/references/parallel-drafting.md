# prd: drafting a long input in parallel

Read when the source text has more than 150 lines or more than 60 bullets (step 4).

A long input is drafted in parallel. When the source text has more
than 150 lines or more than 60 bullets, split it at its top-level
headings into 3 to 6 contiguous line ranges of similar size (never
inside a list or a table), and fork one `prd-drafter` agent per range
in a single message so they run at once, each given the source file
path, its range and the product name. Each returns draft statements
with sources, constraints, ambiguity themes and the gaps it saw. Then
merge in source order: drop a draft that repeats another range's (one
REQ, both lines cited), check every draft against the rules above
(rewrite one that names a solution or is in story form), and only then
number them after the highest existing id. Steps 3, 5, 6 and 7 stay in
this session, because sections, contradictions between ranges and the
register need the whole input. Print the ranges and each drafter's
count; a range whose drafter returned nothing is drafted here, never
skipped.
