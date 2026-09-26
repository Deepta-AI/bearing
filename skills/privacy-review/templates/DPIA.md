# Data protection impact assessment: <feature or system>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. A DPIA is
     written when the scope processes special categories, children's data,
     large-scale monitoring, profiling or a new processor; the privacy
     contact reviews it and signs the decision. Refer to data map rows by
     number rather than restating them. -->

| Field | Value |
| --- | --- |
| Date | <YYYY-MM-DD> |
| Owner | <name> |
| Reviewed by | <privacy contact> |
| Regime | <GDPR / DPDP / both> |
| Trigger | <special category / children / large-scale monitoring / profiling / new processor> |

## 1. Processing described

<!-- What: what data (rows from `docs/privacy/DATA_MAP.md` by number), from
     whom, for what purpose, for how long, shared with whom, on what lawful
     basis.
     Good: every element named here is a data map row; the trigger in the
     table above is visible in this paragraph.
     Example: "Rows 7 to 9 (heart rate, sleep score, date of birth) from
     users of the wellness tab, to personalise plans; kept 12 months after
     last use; shared with no one; basis: explicit consent (wellness_plans)." -->

## 2. Necessity and proportionality

<!-- What: why this data and not less; why this retention and not shorter;
     the alternative considered and rejected.
     Good: each element and the window has its own reason; "we might need it"
     is not a reason, and "forever" needs a lawful basis of its own.
     Example: "Year of birth instead of full date: the plan only needs an age
     band. 12 months, not 36: plans are rebuilt from the last quarter." -->

## 3. Risks to the data subject

<!-- What: the harms to the person the data describes (not to the company),
     with likelihood, severity and where the risk comes from.
     Good: each risk is concrete to this processing and names its source (a
     column, a processor, an export); re-identification from the remaining
     columns counts even when one field is hashed.
     Example: | 2 | re-identification of sleep data via date of birth and
     postcode | medium | high | rows 8 and 9 in the analytics export | -->

| # | Risk | Likelihood | Severity | Source |
| --- | --- | --- | --- | --- |
| 1 | <unauthorised access, loss, re-identification, discrimination, chilling effect> | low / medium / high | low / medium / high | |

## 4. Measures

<!-- What: for every risk above, the measure that reduces it, where it lives
     and the risk left afterwards.
     Good: Where is a `path:line` or a named policy, not an intention; every
     risk number from section 3 appears at least once.
     Example: | 2 | export drops date of birth, keeps age band |
     `internal/export/analytics.go:88` | low | -->

| Risk # | Measure | Where (`path:line` or policy) | Residual |
| --- | --- | --- | --- |

## 5. Rights supported

<!-- What: the mechanism that honours each right for the data in scope.
     Good: each mechanism is a runbook, endpoint, table or command someone
     can run; an empty cell is an open item, not a pass.
     Example: | rectification | profile edit form, `PATCH /v1/me` | -->

| Right | Mechanism |
| --- | --- |
| access / export | `docs/runbooks/dsar.md` |
| erasure | `docs/runbooks/dsar.md` |
| rectification | |
| withdrawal of consent | consents table, purpose key |
| objection | |
| grievance (DPDP) | |

## 6. Decision

<!-- What: the outcome, who signed it, when, and when it is reviewed next.
     Good: "proceed with measures" lists which section 4 rows are the
     conditions; the review date is a real date.
     Example: "Proceed with measures 1 to 3. Signed: Privacy lead,
     2026-10-02. Review due: 2027-04-01." -->

Proceed / proceed with measures / do not proceed. Signed: <name>, <date>.
Review due: <date>.
