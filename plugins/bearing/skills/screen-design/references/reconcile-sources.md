# screen-design: reconcile the sources

Read before the first screen is planned: the eight checks that turn the signed-off documents into a complete state list.

### Reconcile the sources before the first screen

Print each finding; each one either becomes a designed state or a
concern (`ambiguity`, `missing-screen`, `undefined-state`, `dead-end`,
`risk`) raised for its owner. Zero screens and no brief: stop with
"provide flows, stories, code with screens, or a brief".

1. Versions. The flows usually say which PRD version or date they were
written against. When the PRD is newer, read its changelog and every
requirement added or changed since; each that implies a state, a rule
or a screen is designed now and raised as `undefined-state` for
whoever owns the flows. Signed off does not mean complete.
2. Precedence: an Accepted ADR, then the PRD, then the flows, then older
design notes. A design doc an ADR retired (an old palette, an old
layout rule) is never copied from, even when it is the more readable
file.
3. States come from the contract as well as the flows table. For each
screen, list every status in the API's lifecycle it can display and
every error code its calls return (a 409 conflict, a 403 permission
or limit, a 422 validation). Each gets a state or a message that says
what happened and what to do; a generic error for a known code is a
miss. A requirement with no row in the flows (a confirmation, a
second step) gets its state too.
4. What the screen must know before the action. When a requirement says
the person is "not offered" an action that would fail, but the API
only reveals the condition as an error from that action, the UI
cannot know it up front: that is an API gap. Design the state as if
the data existed, label the assumption on the state, raise it, and
never describe the missing field as existing.
5. Rules that combine. Read the requirements that touch the same object
together (a threshold and a limit, a role and a count, two approvers
and one person who holds a limit) and check that every combination
can be satisfied. An impossible or undefined combination is raised
as a question, not settled silently by the design.
6. Data as the product shows it. Values go through the repository's own
formatter (money in minor units, locale digit grouping, the time zone
its date formatter uses), and every fixture value is computed by that
rule, not typed by eye. Thresholds keep their boundary as written
("or more" includes the boundary value). Lists are ordered as the
requirement says, not in fixture-file order.
7. Navigation. An edge to a screen that is out of scope or not designed
is plain text in the design plus a `missing-screen` concern, never a
link or a route.
8. Where the reviewer will open it. The react-shadcn gallery is the
deliverable only when it can run for that reviewer: dependencies are
installed (or may be installed) and someone will serve it. Otherwise
build the HTML bundle, which opens from a file, with the app's token
values copied into it and their source named in a comment; say that
views in the app follow once the dependencies install.
