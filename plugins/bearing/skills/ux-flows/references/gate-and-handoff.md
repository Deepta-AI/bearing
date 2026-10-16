# ux-flows: what the gate fails on

Read when: step 11, after the package is drafted, to know what flows_check.py rejects.

The gate runs on the written file and:

It fails on a screen with no outgoing edge that is not terminal, an
inventory screen in no flowchart, a flowchart screen not in the
inventory, a dialog with no cancel, back or close in Exits, a screen
with no state table, a missing or blank loading, empty, error or
success row, `n/a` without a reason, and zero screens read.
