# System design tenets: <project>

<!-- Template guidance: the five to eight rules this team holds itself to
     while building this system, written to docs/architecture/tenets.md by
     high-level-design after the ADRs are settled. A tenet settles an argument in
     review: it is worth writing only when somebody could plausibly do the
     opposite and a reviewer can point at the breach in a merge request.
     "We write clean code" is not a tenet; "every list endpoint is paginated
     from the first commit" is. Draw each one from an ADR or from what this
     product is; a list that would suit any project is a list nobody reads.
     Delete each comment when you fill its section. -->

Rules this team holds itself to on this project. Each is here because
somebody could plausibly do the opposite, and a reviewer can point at a
breach.

## 1. <tenet title>

<!-- What: one tenet: a bold rule a reviewer can check, a paragraph on why
     this team on this project needs it, and "A breach looks like:" with a
     concrete merge request that breaks it.
     Good: the rule names the mechanism (a WHERE clause, a route prefix, a
     CI check), not a value; the why cites the ADR or the constraint; the
     breach is code or a diff description a reviewer would actually see.
     Example: "**Ownership is a SQL predicate, never a post-fetch check:
     every customer-scoped query carries AND customer_id = $caller.**
     A breach looks like: an MR fetches an invoice by id, then compares
     invoice.CustomerID in Go and returns 403." -->

**<The rule, one or two sentences, checkable in review.>**

<Why this team needs it on this project, citing the ADR or constraint.>

_A breach looks like:_ <the merge request a reviewer would reject>.

## 2. <tenet title>

<!-- What: the next tenet, in the same three parts: bold rule, why, "A
     breach looks like:".
     Good: a different mechanism from tenet 1; five to eight tenets in all,
     each one somebody could plausibly break.
     Example: "**Inside v1, API changes are additive only; a breaking change
     needs the override label on the MR.** A breach looks like: an MR
     renames customer_id to customerId in a response and adds the label to
     make CI pass." -->

**<The rule.>**

<Why.>

_A breach looks like:_ <the merge request>.
