#!/usr/bin/env python3
"""model_check: schema.sql, data-dictionary.csv and data-model.md say the same thing.

data-model writes three views of one Postgres design. They drift the
moment one is edited by hand, and a dictionary that lists a column the
schema dropped is worse than no dictionary. This gate reads all three and
checks, with the standard library only:

  schema.sql
    - opens a transaction (BEGIN;) and closes it (COMMIT;);
    - every CREATE TYPE comes before the first CREATE TABLE;
    - every REFERENCES target is created earlier in the file (FK order);
    - every CREATE TABLE is preceded by a "-- Serves ..." comment;
    - every table has COMMENT ON TABLE and every column COMMENT ON COLUMN;
    - every CHECK constraint is named (CONSTRAINT <name> CHECK ...);
  data-dictionary.csv
    - the header is exactly the eleven columns below;
    - every (table, column) in the SQL is a row, and every row is in the SQL;
    - Nullable agrees with NOT NULL / PRIMARY KEY, Type agrees with the SQL;
    - Description and Why are non-empty; Personal Data is Yes or No;
    - a row with an FK key names its References as table.column that exists;
  data-model.md
    - every table has a heading that names it in backticks;
    - every index and every named CHECK constraint is mentioned;
    - the headline counts (Tables, Columns, Indexes, Personal-data columns)
      match the SQL and the dictionary.

Usage: model_check.py [--dir docs/design] [--schema F] [--dictionary F] [--model F]
Prints one line per problem, then:
  data-model: N tables, N columns, N indexes, N checks, N enums, N personal-data columns, N problems
Exits 1 on any problem, on a missing file, and on zero tables.
"""

import argparse
import csv
import os
import re
import sys

HEADER = [
    "Table",
    "Column",
    "Type",
    "Nullable",
    "Key",
    "Default",
    "References",
    "On Delete",
    "Personal Data",
    "Description",
    "Why",
]
NOT_COLUMNS = {"CONSTRAINT", "PRIMARY", "UNIQUE", "FOREIGN", "CHECK", "EXCLUDE", "LIKE"}
TYPE_STOP = {
    "NOT",
    "NULL",
    "DEFAULT",
    "PRIMARY",
    "REFERENCES",
    "UNIQUE",
    "CHECK",
    "CONSTRAINT",
    "GENERATED",
    "COLLATE",
}
IDENT = r'(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)'
QNAME = IDENT + r"(?:\." + IDENT + r")?"


def unquote(name):
    """public.invoices -> invoices; "Invoices" -> Invoices; others lowercased."""
    name = name.split(".")[-1] if not name.startswith('"') else name
    if name.startswith('"') and name.endswith('"'):
        return name[1:-1]
    return name.lower()


def statements(text):
    """Split SQL on ; outside quotes and comments. Yields (leading comments, body)."""
    out, cur, i, n = [], [], 0, len(text)
    while i < n:
        ch = text[i]
        if text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            if not "".join(cur).strip() or "".join(cur).rstrip().split("\n")[-1].lstrip().startswith("--"):
                cur.append(text[i:j])
            i = j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            i = j
            continue
        if ch in "'\"":
            j = i + 1
            while j < n:
                if text[j] == ch and text.startswith(ch * 2, j):
                    j += 2
                    continue
                if text[j] == ch:
                    break
                j += 1
            cur.append(text[i : j + 1])
            i = j + 1
            continue
        if text.startswith("$$", i):
            j = text.find("$$", i + 2)
            j = n if j < 0 else j + 2
            cur.append(text[i:j])
            i = j
            continue
        if ch == ";":
            out.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    if "".join(cur).strip():
        out.append("".join(cur))
    result = []
    for s in out:
        lines = s.strip("\n").split("\n")
        lead, k = [], 0
        while k < len(lines) and (
            not lines[k].strip() or lines[k].strip().startswith("--")
        ):
            if lines[k].strip():
                lead.append(lines[k].strip()[2:].strip())
            k += 1
        body = "\n".join(lines[k:]).strip()
        if body:
            result.append((lead, body))
    return result


def split_top(body):
    """Split a parenthesised list on commas at depth zero."""
    parts, depth, cur, quote = [], 0, "", ""
    for ch in body:
        if quote:
            cur += ch
            if ch == quote:
                quote = ""
            continue
        if ch in "'\"":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def column_type(rest):
    """The type of a column definition: tokens up to the first constraint keyword."""
    out, depth = [], 0
    for tok in re.findall(r"\([^()]*\)|\S+", rest):
        if depth == 0 and tok.upper() in TYPE_STOP:
            break
        out.append(tok)
    return re.sub(r"\s+", " ", " ".join(out)).strip().lower()


def norm_type(t):
    t = re.sub(r"\s+", " ", t.strip().lower())
    t = re.sub(r"\s*\(\s*", "(", t)
    t = re.sub(r"\s*,\s*", ",", t)
    return re.sub(r"\s*\)", ")", t)


def parse_schema(text, problems):
    tables, order = {}, []
    enums, indexes, checks = [], [], []
    table_comments, column_comments = set(), set()
    first_table_at = None
    has_begin = has_commit = False
    for pos, (lead, body) in enumerate(statements(text)):
        upper = body.upper()
        if re.match(r"^BEGIN(\s+TRANSACTION)?$|^START\s+TRANSACTION$", upper):
            has_begin = True
            continue
        if re.match(r"^COMMIT(\s+TRANSACTION)?$|^END$", upper):
            has_commit = True
            continue
        m = re.match(r"^CREATE\s+TYPE\s+(" + QNAME + r")\s+AS\s+ENUM", body, re.I)
        if m:
            name = unquote(m.group(1))
            enums.append(name)
            if first_table_at is not None:
                problems.append(
                    f"schema.sql: enum {name} is created after the first table; enums go first"
                )
            continue
        m = re.match(
            r"^CREATE\s+(?:UNLOGGED\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?("
            + QNAME
            + r")\s*\((.*)\)[^()]*$",
            body,
            re.I | re.S,
        )
        if m:
            name = unquote(m.group(1))
            if first_table_at is None:
                first_table_at = pos
            if name in tables:
                problems.append(f"schema.sql: table {name} is created twice")
            if not any(re.match(r"^Serves\b", c, re.I) for c in lead):
                problems.append(
                    f"schema.sql: table {name} has no '-- Serves US-...' comment before it"
                )
            cols = {}
            for part in split_top(m.group(2)):
                cm = re.match(r"^(" + IDENT + r")\s+(.*)$", part, re.S)
                if not cm:
                    continue
                word = cm.group(1)
                rest = cm.group(2)
                if word.upper() in NOT_COLUMNS:
                    if word.upper() == "PRIMARY":
                        for c in re.findall(
                            IDENT, re.sub(r"^KEY\s*", "", rest, flags=re.I)
                        ):
                            if c.lower() in cols:
                                cols[c.lower()]["notnull"] = True
                    for r in re.findall(r"REFERENCES\s+(" + QNAME + r")", part, re.I):
                        refcheck(name, unquote(r), tables, problems)
                    checks.extend(named_checks(name, part, problems))
                    continue
                col = unquote(word)
                ctype = column_type(rest)
                notnull = bool(
                    re.search(r"\bNOT\s+NULL\b|\bPRIMARY\s+KEY\b", rest, re.I)
                )
                cols[col] = {"type": ctype, "notnull": notnull}
                for r in re.findall(r"REFERENCES\s+(" + QNAME + r")", rest, re.I):
                    refcheck(name, unquote(r), tables, problems)
                checks.extend(named_checks(name, rest, problems))
            tables[name] = cols
            order.append(name)
            continue
        m = re.match(
            r"^ALTER\s+TABLE\s+(?:ONLY\s+)?(" + QNAME + r")\s+(.*)$", body, re.I | re.S
        )
        if m:
            checks.extend(named_checks(unquote(m.group(1)), m.group(2), problems))
            continue
        m = re.match(
            r"^CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?("
            + IDENT
            + r")\s+ON\s+("
            + QNAME
            + r")",
            body,
            re.I,
        )
        if m:
            indexes.append((unquote(m.group(1)), unquote(m.group(2))))
            continue
        if re.match(r"^CREATE\s+(?:UNIQUE\s+)?INDEX\s+ON\b", body, re.I):
            problems.append(
                "schema.sql: an index has no name; name it so the document can say what it serves"
            )
            continue
        m = re.match(
            r"^COMMENT\s+ON\s+TABLE\s+(" + QNAME + r")\s+IS\s+'(.*)'$",
            body,
            re.I | re.S,
        )
        if m:
            if m.group(2).strip():
                table_comments.add(unquote(m.group(1)))
            continue
        m = re.match(
            r"^COMMENT\s+ON\s+COLUMN\s+("
            + IDENT
            + r"(?:\."
            + IDENT
            + r"){1,2})\s+IS\s+'(.*)'$",
            body,
            re.I | re.S,
        )
        if m:
            parts = re.findall(IDENT, m.group(1))
            if m.group(2).strip():
                column_comments.add((unquote(parts[-2]), unquote(parts[-1])))
            continue
    if not has_begin:
        problems.append("schema.sql: no BEGIN; the file must apply in one transaction")
    if not has_commit:
        problems.append("schema.sql: no COMMIT; the file must apply in one transaction")
    for t in order:
        if t not in table_comments:
            problems.append(f"schema.sql: table {t} has no COMMENT ON TABLE")
        for c in tables[t]:
            if (t, c) not in column_comments:
                problems.append(f"schema.sql: column {t}.{c} has no COMMENT ON COLUMN")
    for iname, itable in indexes:
        if itable not in tables:
            problems.append(
                f"schema.sql: index {iname} is on {itable}, which is not a table here"
            )
    return tables, order, enums, indexes, checks


def refcheck(table, target, tables, problems):
    if target != table and target not in tables:
        problems.append(
            f"schema.sql: {table} references {target} before {target} is created (foreign-key order)"
        )


def named_checks(table, text, problems):
    names = []
    for m in re.finditer(
        r"(?:CONSTRAINT\s+(" + IDENT + r")\s+)?CHECK\s*\(", text, re.I
    ):
        if m.group(1):
            names.append(unquote(m.group(1)))
        else:
            problems.append(
                f"schema.sql: {table} has an unnamed CHECK; write CONSTRAINT <name> CHECK so the document can give its reason"
            )
    return names


def read_dictionary(path, problems):
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    if not rows:
        problems.append("data-dictionary.csv: empty, no header")
        return []
    header = [h.strip() for h in rows[0]]
    if header != HEADER:
        problems.append(
            "data-dictionary.csv: header must be "
            + ",".join(HEADER)
            + " (got "
            + ",".join(header)
            + ")"
        )
        return []
    out = []
    for n, r in enumerate(rows[1:], 2):
        if not any(c.strip() for c in r):
            continue
        if len(r) != len(HEADER):
            problems.append(
                f"data-dictionary.csv:{n}: {len(r)} fields, wanted {len(HEADER)}"
            )
            continue
        out.append(dict(zip(HEADER, [c.strip() for c in r]), line=n))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dir", default="docs/design")
    ap.add_argument("--schema")
    ap.add_argument("--dictionary")
    ap.add_argument("--model")
    a = ap.parse_args()
    schema = a.schema or os.path.join(a.dir, "schema.sql")
    dictionary = a.dictionary or os.path.join(a.dir, "data-dictionary.csv")
    model = a.model or os.path.join(a.dir, "data-model.md")
    problems = []
    missing = [p for p in (schema, dictionary, model) if not os.path.isfile(p)]
    if missing:
        for p in missing:
            print(f"missing: {p}")
        print(
            "data-model: 0 tables, nothing checked (missing " + ", ".join(missing) + ")"
        )
        return 1

    tables, order, enums, indexes, checks = parse_schema(
        open(schema, encoding="utf-8").read(), problems
    )
    rows = read_dictionary(dictionary, problems)
    doc = open(model, encoding="utf-8").read()
    ncols = sum(len(c) for c in tables.values())

    seen = set()
    pii = 0
    for r in rows:
        t, c, where = (
            r["Table"].lower(),
            r["Column"].lower(),
            f"data-dictionary.csv:{r['line']}",
        )
        if (t, c) in seen:
            problems.append(f"{where}: {t}.{c} is listed twice")
        seen.add((t, c))
        if t not in tables or c not in tables[t]:
            problems.append(
                f"{where}: {t}.{c} is in the dictionary but not in schema.sql"
            )
            continue
        sql = tables[t][c]
        if r["Nullable"] not in ("Yes", "No"):
            problems.append(
                f"{where}: {t}.{c} Nullable is '{r['Nullable']}', wanted Yes or No"
            )
        elif (r["Nullable"] == "No") != sql["notnull"]:
            problems.append(
                f"{where}: {t}.{c} Nullable is {r['Nullable']} but schema.sql says {'NOT NULL' if sql['notnull'] else 'nullable'}"
            )
        if norm_type(r["Type"]) != norm_type(sql["type"]):
            problems.append(
                f"{where}: {t}.{c} Type is '{r['Type']}' but schema.sql says '{sql['type']}'"
            )
        if r["Personal Data"] not in ("Yes", "No"):
            problems.append(
                f"{where}: {t}.{c} Personal Data is '{r['Personal Data']}', wanted Yes or No"
            )
        elif r["Personal Data"] == "Yes":
            pii += 1
        if not r["Description"]:
            problems.append(f"{where}: {t}.{c} has no Description")
        if not r["Why"]:
            problems.append(
                f"{where}: {t}.{c} has no Why (the acceptance criterion or rule it exists for)"
            )
        if "FK" in r["Key"].upper():
            ref = r["References"].lower()
            rt, _, rc = ref.partition(".")
            if not rc or rt not in tables or rc not in tables[rt]:
                problems.append(
                    f"{where}: {t}.{c} is an FK but References '{r['References']}' is not a table.column in schema.sql"
                )
    for t in order:
        for c in tables[t]:
            if (t, c) not in seen:
                problems.append(
                    f"data-dictionary.csv: {t}.{c} is in schema.sql but not in the dictionary"
                )

    for t in order:
        if not re.search(r"^#{2,4} .*`" + re.escape(t) + r"`", doc, re.M):
            problems.append(f"data-model.md: no heading names table `{t}`")
    for iname, _ in indexes:
        if iname not in doc:
            problems.append(
                f"data-model.md: index {iname} is not listed with the query it serves"
            )
    for cname in checks:
        if cname not in doc:
            problems.append(
                f"data-model.md: constraint {cname} is not listed with its rationale"
            )
    for label, want in (
        ("Tables", len(order)),
        ("Columns", ncols),
        ("Indexes", len(indexes)),
        ("Personal-data columns", pii),
    ):
        m = re.search(r"\**" + re.escape(label) + r":?\**:?\s*(\d+)", doc)
        if not m:
            problems.append(f"data-model.md: headline has no '{label}: N'")
        elif int(m.group(1)) != want:
            problems.append(
                f"data-model.md: headline says {label}: {m.group(1)}, the files say {want}"
            )

    if not order:
        problems.append("schema.sql: 0 tables, nothing to check")
    for p in problems:
        print(p)
    print(
        f"data-model: {len(order)} tables, {ncols} columns, {len(indexes)} indexes, "
        f"{len(checks)} checks, {len(enums)} enums, {pii} personal-data columns, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
