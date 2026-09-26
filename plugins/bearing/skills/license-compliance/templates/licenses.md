# Licence inventory

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This inventory
     answers "may we ship it" for every third-party component, from the SBOM
     and the policy; it is read by the release approver and legal. The counts
     line is the gate's printed line, never hand-counted.
     The table: one row per component in the SBOM. Verdict is the gate's;
     "unknown" is not "probably fine" and stays unknown until a person reads
     the package and an exception is written. An expression is kept whole
     (`MIT OR GPL-2.0`), since the gate judges it, not a reader.
     Example: | lodash | 4.17.21 | MIT | allowed | runtime | yes | | -->

Generated from `docs/compliance/sbom.cdx.json` on <YYYY-MM-DD> by `scripts/license-gate.py`.
Policy: `docs/compliance/license-policy.yml`. Result: <N> components, allowed <A>, denied <D>, unknown <U>.

| Component | Version | Licence (SPDX) | Verdict | Scope | Attribution required | Note |
| --- | --- | --- | --- | --- | --- | --- |
| <name> | <version> | <id or expression> | allowed / denied / unknown / exception | runtime / dev | yes / no | |

## Exceptions in force

<!-- What: every entry in the policy's `exceptions:`, one row each, so a
     reader sees why a denied or unknown component still passes.
     Good: a named owner, the reason a person wrote after reading the
     package (not "needed"), the date granted and a review date.
     Example: | fontkit@2.0.2 | licence field empty in the SBOM; LICENSE in the tarball is MIT | Kavya R. | 2026-09-10 | 2027-03-10 | -->

| Component | Reason | Owner | Granted | Review by |
| --- | --- | --- | --- | --- |

## Denied, to resolve

<!-- What: every component the gate denied, with the way out chosen:
     replace it, or a written exception in the policy with owner and reason.
     Good: each row has an owner and a task id; a copyleft dev dependency
     that never ships is solved by scope in the policy (`dev: allow`), not by
     deleting the row.
     Example: | ghostscript4js@3.2.3 | AGPL-3.0-only | pdf-lib 1.17.1 (MIT) | Rahul S. | DEP-88 | -->

| Component | Licence | Replace with | Owner | Task |
| --- | --- | --- | --- | --- |
