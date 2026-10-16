# data-model: writing the four files and the review

Read when: steps 9 to 11: the file layouts, the critic brief and what the gate fails on.

9. Write the four files (a new model; for a revision see Revising), from
this skill's templates, replacing the worked example: `docs/design/data-model.md` (headline line: store,
tables, columns, indexes, personal-data columns);
`docs/design/schema.sql` (one `BEGIN;` ... `COMMIT;`, enum types first,
tables in foreign-key order, a `-- Serves US-...` comment before each
table, `COMMENT ON TABLE` and `COMMENT ON COLUMN` for every table and
column, then its indexes); `docs/design/data-dictionary.csv` (one row
per Postgres column, header `Table,Column,Type,Nullable,Key,Default,References,On Delete,Personal Data,Description,Why`);
`docs/design/erd.md` (mermaid `erDiagram` and one sentence per
relationship). With no Postgres store, `schema.sql`, the dictionary and
the gate are "n/a (no postgres store)".

10. Review: fork `critic` with the paths of `data-model.md` and
 `schema.sql` and the stories file, asking it to argue against the
 schema from the acceptance criteria and the Design checks below, and
 grade each finding BLOCKER
 (the schema cannot serve a criterion, or does not apply), MAJOR (a
 criterion is served wrongly or a guarantee is missing), MINOR or NIT,
 each with the table, the failure and the fix. Fix what can be fixed in
 this run and mark it fixed; write the rest under "What the review
 found" with Status open. Then write "Open concerns": each tagged
 `[conflict]`, `[gap]`, `[ambiguity]`, `[risk]` or `[scope]`, with an
 owner, a date and "Blocks development: yes | no".

 It fails on zero tables, on any table or column in the SQL but not in
 the dictionary or the reverse, on an empty Why, on a table or column
 with no `COMMENT ON`, on an unnamed CHECK, on FK order, and on
 headline counts that disagree. Fix and rerun until it prints 0
