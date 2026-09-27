# Data pipeline review checklist

For each item, either find the concrete failure or write "none found".

## Idempotency and partitions
- An incremental model without `unique_key`, or with a key that does not
  identify a row (a re-run duplicates).
- A model that reads outside its window (`where order_date >= start` with
  no upper bound, or no window at all on a large source).
- A task that appends without a delete or merge for its interval; a task
  whose output depends on when it ran (`now()`, `current_date`) instead of
  the run's data interval.
- A backfill done with `--full-refresh`, or a DAG with `catchup=True` and
  no `max_active_runs=1`.
- delete+insert keyed on (day, dimension) or on day alone with no window
  delete: a group or a day that vanished keeps its old row.
- A staging model over an append or CDC table without latest-row
  deduplication and a `unique` test on the id.
- A lookback shorter than the time the source's rows can change; a
  backfill that starts at the change date instead of the first bad run's
  window start, or reaches days raw no longer holds in full.
- An Airflow 3 DAG on a cron string or preset whose tasks read the data
  interval (zero length); a model built before its source lands.

## SQL and models
- `select *` in a model; a column that reaches a mart uncast or unnamed.
- A mart reading a source or seed directly; an intermediate model queried
  by a consumer; a staging model with business logic.
- A join without an explicit alias on every column; a fan-out join without
  a comment saying the grain is intended.
- A `case` on a status string that misses a value the `accepted_values`
  test allows.
- An ephemeral or view model used where a table would be read many times.

## Tests and contracts
- A new mart or a new mart column without a yml entry and `data_tests`.
- A key without `unique` and `not_null`; a foreign key without
  `relationships`; an enumeration without `accepted_values`; a measure
  without a range expectation.
- A test removed or its severity dropped to `warn` to get a green run.
- A schema change (`on_schema_change`) set to `ignore` or `append_new_columns`
  without a note on who reads the table.

## DAGs
- Network, a warehouse call, `Variable.get` or a file read at module
  level; an import that fails without a credential.
- A task with no retries, no owner, no timeout; a DAG without tags.
- `depends_on_past=True` without a reason; a schedule that overlaps its
  own runtime without `max_active_runs=1`.
- A bash command built from an untrusted value; a secret in a
  `bash_command` or an env dict.

## Configuration and secrets
- A credential in `profiles.yml.example`, `dbt_project.yml`, a DAG, `.env.example`
  or a test fixture.
- An adapter or warehouse switched without an ADR; a `packages.yml`
  dependency added unasked.
- A model or DAG that hard-codes a schema, database or path that differs
  between environments.

## Tests (pytest)
- A bug fix without a reproducing test.
- A layout rule relaxed in `tests/test_dbt_layout.py` to let a change in.
- A DAG test that only checks the file imports, not the window, retries
  and ordering.

## Hygiene
- `# noqa` or a sqlfluff `noqa` added without a rule code and a reason; a
  lint rule disabled; `uv.lock` edited by hand or stale.
- Generated output (`dbt/target`, compiled SQL) committed.
- Em dash in a comment, description or doc.
