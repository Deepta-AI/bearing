# data-model: sources, entities, relationships and stores

Read when: steps 1 to 4: reading the sources, then writing the entity, relationship and store sections.

1. Read the sources under Inputs, each printed as read or absent: the
stories, the HLD data section, ADRs that choose a store
(`grep -il 'postgres\|mongo\|clickhouse' docs/adr/`), existing
migrations and models. Stores from `--stores` or the ADRs; none named
means Postgres (the default in `database`). Read the matching
references from the plugin root:
`${CLAUDE_PLUGIN_ROOT}/skills/database/references/postgres.md`,
`mongodb.md`, `clickhouse.md`, and `migration-patterns.md`. Zero
stories and zero entities in the code: ask the one question under
Inputs and model from the answer.
2. Entities: one row each with owner (service or module), lifecycle
(created by, changed by, ended by: delete, archive, expiry; every
writer path), the
`US-nn-nnn` ids it serves, PII yes or no, retention. An entity no
story reads or writes is cut and listed under "not modelled".
3. Relationships: one row per foreign key with its cardinality, FK
column, `ON DELETE` and why; the mermaid `erDiagram` (every entity,
every relationship with its cardinality, the FK columns named) goes to
`erd.md` with one sentence per relationship.
4. Why these stores: per store, what it holds and why, with a Considered
| Why not table naming the requirement each rejected store fails.
