# Analysis: <name>

<!-- Template guidance: the result of one experiment, read against the
     decision table written at design time. Sections run in order and the
     analysis stops at the first failure. Every comment says what goes there
     (What), what a strong entry has (Good) and an example (Example). Delete
     each comment when you fill its section. -->

Analysed: <YYYY-MM-DD>   Data: <results.csv | pasted counts>   Window: <start> to <end>

## Data check

<!-- What: whether the export measures what the design asked for.
     Good: same metric definition and outcome window, same unit, window
     ending at the planned end, units whose outcome window had not closed
     excluded; any mismatch is stated before any number is read.
     Example: "Export counts orders up to the export time, not within 7
     days; runs to 25 Sep against a planned end of 22 Sep. Not the
     pre-registered read." -->

Design: <metric, window, unit, planned end>. Export: <same | differs: how>.

## Sample ratio

<!-- What: exposed counts per variant against the planned split, and the
     chi-square p-value, checked before any metric.
     Good: computed with python3, overall and per segment in the export;
     p under 0.001 is a mismatch: the split is broken, no metric is read as
     a result; the imbalanced segment names the exposure code to open, and
     the direction of the bias is stated.
     Example: "Overall p = 7.7e-18; web p = 9.9e-27, app p = 0.75. Cause:
     treatment counted after the banner image loads. MISMATCH." -->

| Variant | Planned share | Exposed | Observed share |
| --- | --- | --- | --- |
| control | <50>% | <n0> | <s0>% |
| treatment | <50>% | <n1> | <s1>% |

| Segment | Control | Treatment | Chi-square p |
| --- | --- | --- | --- |
| <segment> | <n0> | <n1> | <p> |

Chi-square p = <p>. Result: ok | MISMATCH (cause <file:line>; analysis stopped).

## Power

<!-- What: the planned n per variant against the smallest exposed count.
     Good: below the planned n the result says "underpowered, N of n"; the
     decision table then allows one extension, not a verdict.
     Example: "Planned n per variant: 14,112. Smallest exposed: 11,930.
     Result: underpowered (11,930 of 14,112)." -->

Planned n per variant: <n>. Smallest exposed: <min>. Result: full | underpowered (<min> of <n>).

## Primary metric

<!-- What: rates per variant, the absolute and relative lift, z, p and the
     95 percent confidence interval.
     Good: every number comes from the counts in the table, computed with
     python3, and the command is kept below the table; significance decides,
     the MDE only sized the test.
     Example: "Lift: 0.012 absolute (11.8% relative). z = 2.71, p = 0.007,
     95% CI [0.003, 0.021]." -->

| Variant | Exposed | Converted | Rate |
| --- | --- | --- | --- |
| control | <n0> | <c0> | <p0> |
| treatment | <n1> | <c1> | <p1> |

Lift: <abs> absolute (<rel>% relative). z = <z>, p = <p>, 95% CI [<lo>, <hi>].

## Guardrails

<!-- What: every guardrail from the design, control against treatment.
     Good: breached is judged in the harm direction written at design; a
     breach means kill even when the primary is up; a guardrail with no
     data is "not checked", never "no".
     Example: "`checkout_payment_failed` | 0.021 | 0.022 | no" -->

| Guardrail | Control | Treatment | Breached |
| --- | --- | --- | --- |
| <event> | <v> | <v> | no | yes | not checked |

## Decision

<!-- What: ship, kill or extend, and the decision table row that applied.
     Good: quotes the row, not a new argument; the follow-up names the flag
     removal task.
     Example: "ship because primary up with p < 0.05 (CI excludes zero)
     at full sample and no guardrail breached." -->

<ship | kill | extend | rerun> because <row of the decision table that applied, or the data check or SRM failure>.

Follow-up: remove the flag `<flag_name>` with the feature-flags skill (<TASK-ID> | tbd)
