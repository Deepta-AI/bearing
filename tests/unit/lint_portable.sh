#!/usr/bin/env bash
# tests/unit/lint_portable.sh: bin/lint-portable.py rejects commands that are
# not on every CI image (perl is missing from bash:3.2) or behave differently
# on macOS (sed -i, grep -P, readlink -f, date -d), in command position only;
# quoted strings and comments pass; zero files fail.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LP="$KIT/bin/lint-portable.py"

t_begin "non-portable commands in command position are named with file and line"
d="$(tmpdir)"
cat > "$d/a.sh" <<'SH'
#!/usr/bin/env bash
sed -i 's/a/b/' f
x="$(grep -P '\d' f)" && perl -pi -e 's/a/b/' f
readlink -f . | date -d now
SH
assert_exit 1 python3 "$LP" "$d/a.sh"
assert_contains "$T_OUT" "a.sh:2: sed -i"
assert_contains "$T_OUT" "a.sh:3: grep -P"
assert_contains "$T_OUT" "a.sh:3: perl"
assert_contains "$T_OUT" "a.sh:4: readlink -f"
assert_contains "$T_OUT" "a.sh:4: date -d"
assert_contains "$T_OUT" "lint-portable: 1 files, 5 problems"
t_end

t_begin "quoted strings, comments and portable forms pass"
d="$(tmpdir)"
cat > "$d/b.sh" <<'SH'
#!/usr/bin/env bash
# sed -i is GNU only; this comment is fine
row DENY "perl -e 'system(1)'"
sed -i.bak 's/a/b/' f && rm f.bak
replace_in f a b
SH
assert_exit 0 python3 "$LP" "$d/b.sh"
assert_contains "$T_OUT" "lint-portable: 1 files, 0 problems"
t_end

t_begin "zero files is a failure; with no files the repository's scripts are read"
assert_exit 1 python3 "$LP" --root "$(tmpdir)"
assert_contains "$T_OUT" "lint-portable: 0 files, nothing checked"
assert_exit 0 python3 "$LP"
assert_contains "$T_OUT" "files, 0 problems"
t_end

t_summary
