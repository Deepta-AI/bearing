# high-level-design: revising an existing HLD

Read when the output file already exists, so this run is a revision.

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). A revision that leaves the goal and non-goals as they were keeps section 1 agreed and skips step 2's question; a changed goal goes back through step 2.
A section the revision changes is re-sourced, not edited from the old
text: re-read the code, README and ADRs behind it as step 4 asks, and
recompute its numbers. The previous version's conclusions are claims to
check, not inputs; one that no longer holds, or never did, is a row in
the changes table. Check what was actually built before writing about
cutover: grep for the old design's handlers, tables and flags, because a
design that was approved but never built has no data or jobs to migrate.
Change what the request changes and what it invalidates, nothing else;
a problem noticed elsewhere in the old design goes under open questions,
not into a redesign nobody asked for. Tenets and decisions you touch
must agree with the revised text.
