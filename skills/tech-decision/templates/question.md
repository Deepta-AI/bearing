<!-- Template guidance: the block printed to the user for one decision,
     one per turn, then the skill stops and waits for the answer. Delete each
     comment when you fill the block. -->

### Decision: <key> (<n> of <total>)

<!-- What: the facts that decide this key, three to five options with what
     each is good at and costs, one recommendation, its flip condition and
     the question.
     Good: the facts come from the repository, ADRs and PRD read in step 2,
     and the reasons cite them, never the catalogue default alone; the
     user's own pick is listed first even when it is not recommended; the
     flip condition is a fact someone could check.
     Example: "It flips to Kafka if you need to replay a month of events
     into a new consumer." -->

Facts that matter: <one line>.
Not in the repository: <a fact that would change this answer, and what
was assumed about it> | none.

| Option | Good at | Costs |
| --- | --- | --- |
| **<user's pick, if any>** | | |
| <option> | | |
| <option> | | |

**Recommendation: <option>.** <reason 1>. <reason 2>. <reason 3 if any>.
It flips to <other option> if <condition>.

Which do you want: <A>, <B>, <C>, or defer?
