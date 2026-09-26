#!/usr/bin/env bash
# tests/unit/data_model_check.sh: plugins/bearing/skills/data-model/scripts/model_check.py
# (schema.sql, data-dictionary.csv and data-model.md agree: every table and
# column in both, a Why per column, COMMENT ON everywhere, named CHECKs, FK
# order, enums first, headline counts) and scripts/apply_check.sh (SKIPPED
# without docker, fails on a missing file). The shipped templates are the
# passing fixture, so they cannot drift apart either.
set -u
. "$(dirname "$0")/../lib/assert.sh"
MC="$KIT/plugins/bearing/skills/data-model/scripts/model_check.py"
AC="$KIT/plugins/bearing/skills/data-model/scripts/apply_check.sh"
TPL="$KIT/plugins/bearing/skills/data-model/templates"

fixture() { # fixture <dir>: the three template files, as a skill run writes them
  cp "$TPL/schema.sql" "$TPL/data-dictionary.csv" "$TPL/data-model.md" "$1/"
}
edit() { # edit <file> <sed expression>: portable in-place edit (GNU and BSD sed)
  sed -i.bak "$2" "$1" && rm -f "$1.bak"
}

t_begin "the shipped templates agree with each other"
d="$(tmpdir)"; fixture "$d"
assert_exit 0 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "data-model: 2 tables, 15 columns, 3 indexes, 4 checks, 1 enums, 2 personal-data columns, 0 problems"
t_end

t_begin "a column in one file and not the other fails, both ways"
d="$(tmpdir)"; fixture "$d"
edit "$d/schema.sql" 's/^    due_on date NOT NULL,$/    due_on date NOT NULL, memo text,/'
printf "COMMENT ON COLUMN invoices.memo IS 'x';\n" >> "$d/schema.sql"
grep -v '^customers,updated_at,' "$d/data-dictionary.csv" > "$d/dd" && mv "$d/dd" "$d/data-dictionary.csv"
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "invoices.memo is in schema.sql but not in the dictionary"
assert_contains "$T_OUT" "customers.updated_at is in schema.sql but not in the dictionary"
printf 'invoices,ghost,text,Yes,,,,,No,A column nobody created.,US-01-002 AC9.\n' >> "$d/data-dictionary.csv"
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "invoices.ghost is in the dictionary but not in schema.sql"
t_end

t_begin "an empty Why, a wrong Nullable or Type, and a dangling FK reference fail"
d="$(tmpdir)"; fixture "$d"
edit "$d/data-dictionary.csv" 's/^invoices,due_on,date,No,\(.*\),US-01-003 AC4: overdue invoices are flagged after the due date.$/invoices,due_on,date,Yes,\1,/'
edit "$d/data-dictionary.csv" 's/^invoices,currency,char(3)/invoices,currency,varchar(3)/'
edit "$d/data-dictionary.csv" 's/,customers.id,RESTRICT,/,customers.uid,RESTRICT,/'
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "invoices.due_on has no Why"
assert_contains "$T_OUT" "invoices.due_on Nullable is Yes but schema.sql says NOT NULL"
assert_contains "$T_OUT" "invoices.currency Type is 'varchar(3)' but schema.sql says 'char(3)'"
assert_contains "$T_OUT" "References 'customers.uid' is not a table.column"
t_end

t_begin "a missing COMMENT ON, an unnamed CHECK, FK order, a late enum and no transaction fail"
d="$(tmpdir)"; fixture "$d"
grep -v -e "^COMMENT ON TABLE invoices" -e "^COMMENT ON COLUMN customers.email" "$d/schema.sql" > "$d/s" && mv "$d/s" "$d/schema.sql"
edit "$d/schema.sql" 's/    amount_minor bigint NOT NULL,/    amount_minor bigint NOT NULL CHECK (amount_minor < 1000000000),/'
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "table invoices has no COMMENT ON TABLE"
assert_contains "$T_OUT" "column customers.email has no COMMENT ON COLUMN"
assert_contains "$T_OUT" "invoices has an unnamed CHECK"
fixture "$d"
edit "$d/schema.sql" 's/REFERENCES customers (id)/REFERENCES payers (id)/'
edit "$d/schema.sql" 's/^BEGIN;$//'
printf "CREATE TYPE late_kind AS ENUM ('a');\n" >> "$d/schema.sql"
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "invoices references payers before payers is created (foreign-key order)"
assert_contains "$T_OUT" "enum late_kind is created after the first table"
assert_contains "$T_OUT" "no BEGIN"
t_end

t_begin "the document must name every table, index and check and carry true counts"
d="$(tmpdir)"; fixture "$d"
edit "$d/data-model.md" 's/\*\*Indexes:\*\* 3/**Indexes:** 4/'
edit "$d/data-model.md" 's/^- `idx_invoices_customer_id`:/- the customer index:/'
edit "$d/data-model.md" 's/^### `customers`: Customers/### Customers/'
edit "$d/data-model.md" 's/^- `chk_invoices_currency_iso`:/- the currency check:/'
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "headline says Indexes: 4, the files say 3"
assert_contains "$T_OUT" "index idx_invoices_customer_id is not listed"
assert_contains "$T_OUT" "no heading names table \`customers\`"
assert_contains "$T_OUT" "constraint chk_invoices_currency_iso is not listed"
t_end

t_begin "empty input and missing files fail with the count"
d="$(tmpdir)"; fixture "$d"
printf 'BEGIN;\nCOMMIT;\n' > "$d/schema.sql"
head -1 "$TPL/data-dictionary.csv" > "$d/data-dictionary.csv"
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "0 tables, nothing to check"
assert_contains "$T_OUT" "data-model: 0 tables, 0 columns"
rm "$d/data-dictionary.csv"
assert_exit 1 python3 "$MC" --dir "$d"
assert_contains "$T_OUT" "data-model: 0 tables, nothing checked (missing $d/data-dictionary.csv)"
t_end

t_begin "apply_check: SKIPPED without docker, a missing file fails"
d="$(tmpdir)"; fixture "$d"
p="$(minimal_path bash head tail grep printf)"
assert_exit 0 env PATH="$p" bash "$AC" "$d/schema.sql"
assert_contains "$T_OUT" "schema-apply: SKIPPED (docker not available)"
assert_exit 1 env PATH="$p" bash "$AC" "$d/none.sql"
assert_contains "$T_OUT" "is missing or empty, nothing applied"
t_end

t_summary
