# high-level-design: review and gate

Read at steps 9 and 10: the mandatory critic review, open questions, and the arch_check gate.

9. Review, mandatory. Fork `critic` (Agent tool) in graded mode (pass model: "opus" on the Agent call) with
the HLD, the ADR directory, `docs/architecture/`, the backlog, the
data model and the Traps list in references/traps.md, asking it to check each trap that
applies. Write its findings verbatim under section 16 with
`Reviewed by: critic, <date>` and `Status: open` on each. Fix
what the user agrees to, marking it `fixed (<where>)`, or record who
accepted it. Status stays Draft or Reviewed while a BLOCKER is open.
10. Open questions and assumptions (section 17), each with an owner and a
date. Write the HLD, then run the gate:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/high-level-design/scripts/arch_check.py" docs/design/<kebab-title>-hld.md --adr-dir <ADR directory>`.
Fix every problem it prints and rerun until `Gate: passed`; a
problem you cannot fix goes in the contract. Print the output
contract.
