#!/usr/bin/env bash
# tests/unit/feature_flags_check.sh: plugins/bearing/skills/feature-flags/scripts/flags_check.py
# passes when the Go flags module and the register agree, every flag has an
# owner and a future removal date, and code reads flags only through the
# module; fails on each mismatch direction, a removed flag still in code, a
# missing owner, a missing or past date, a key or FLAG_ read outside the
# module, a removed flag still read by a client file or set in deploy
# config, a FLAG_ setting for no flag, and on empty input. Reads a team's
# register without an "Active flags" heading as it is, lists client reads
# and per-environment values (naming deployed files that leave a flag
# unset), fails on a false, 0 or off setting a lenient parser reads as on,
# and exempts test files.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/feature-flags/scripts/flags_check.py"

# fixture <dir>: a Go service with two flags, a register and one handler.
fixture() {
  mkdir -p "$1/internal/flags" "$1/internal/http" "$1/docs/operations"
  cat > "$1/internal/flags/flags.go" <<'GO'
package flags

type Flag string

// Names: one typed enumeration.
const (
	NewCheckout         Flag = "new_checkout"
	KillRecommendations Flag = "kill_recommendations"
)

func Enabled(name Flag) bool { return lookup("FLAG_" + string(name)) }
GO
  printf 'package http\n\nfunc Checkout() { if flags.Enabled(flags.NewCheckout) { return } }\n' > "$1/internal/http/checkout.go"
  cat > "$1/docs/operations/flags.md" <<'MD'
# Feature flags register

## Active flags

| Flag | Default | Kind | Owner | On means | Removal task | Target date | Added |
| --- | --- | --- | --- | --- | --- | --- | --- |
| new_checkout | off | release | payments-oncall | new flow | PROJ-12 | 2026-12-21 | 2026-09-22 |
| kill_recommendations | off | kill switch | growth-oncall | empty list | tbd | 2027-09-22 | 2026-09-22 |

## Removed flags

| Flag | Kind | Removed | Outcome |
| --- | --- | --- | --- |
| old_search | release | 2026-09-01 | graduated |
MD
}
run() { (cd "$1" && python3 "$CHK" --today 2026-09-23); }

t_begin "module, register and code agree"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "feature-flags: 2 flags in internal/flags/flags.go, 2 in the register, 0 mismatches, 0 past their removal date, 1 removal tasks tbd, 0 reads outside the module in 1 source files, 0 client reads, 0 config files, 0 problems"
t_end

t_begin "a flag on one side only and a removed flag still in code are mismatches"
d="$(tmpdir)/mismatch"; fixture "$d"
sed -i.bak 's/^)$/\tOldSearch Flag = "old_search"\n\tBeta Flag = "beta_banner"\n)/' "$d/internal/flags/flags.go"
sed -i.bak '/^| kill_recommendations/d' "$d/docs/operations/flags.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: beta_banner: in internal/flags/flags.go but not in the register"
assert_contains "$T_OUT" "problem: old_search: listed as removed but still in internal/flags/flags.go"
assert_contains "$T_OUT" "problem: kill_recommendations: in internal/flags/flags.go but not in the register"
t_end

t_begin "no owner, no date and a past date fail"
d="$(tmpdir)/dates"; fixture "$d"
sed -i.bak 's/| payments-oncall |/|  |/; s/2026-12-21/2026-09-01/; s/| 2027-09-22 |/| soon |/' "$d/docs/operations/flags.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: new_checkout: no owner"
assert_contains "$T_OUT" "problem: new_checkout: removal date 2026-09-01 is past (today 2026-09-23)"
assert_contains "$T_OUT" "problem: kill_recommendations: no removal date (target date 'soon')"
assert_contains "$T_OUT" "1 past their removal date"
t_end

t_begin "reads around the module are counted and fail"
d="$(tmpdir)/reads"; fixture "$d"
printf 'package jobs\n\nvar on = os.Getenv("FLAG_NEW_CHECKOUT")\nvar k = "kill_recommendations"\n' > "$d/internal/http/job.go"
printf 'const x = import.meta.env.VITE_FLAG_OTHER;\n' > "$d/internal/http/web.ts"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: internal/http/job.go:3: reads a FLAG_ variable outside the module"
assert_contains "$T_OUT" "problem: internal/http/job.go:4: reads flag kill_recommendations outside the module"
assert_contains "$T_OUT" "problem: internal/http/web.ts:1: reads a FLAG_ variable outside the module"
assert_contains "$T_OUT" "3 reads outside the module in 3 source files"
t_end

t_begin "a register without an Active heading and with its own column names is read as it is"
d="$(tmpdir)/ownreg"; fixture "$d"
cat > "$d/docs/operations/flags.md" <<'MD'
# Feature flags register

| Flag | Default | Owner | On means | Removal ticket | Target date | Added |
| --- | --- | --- | --- | --- | --- | --- |
| new_checkout | off | payments-oncall | new flow | PROJ-12 | 2026-12-21 | 2026-09-22 |
| kill_recommendations | off | growth-oncall | empty list | PROJ-13 | 2027-09-22 | 2026-09-22 |
MD
assert_exit 0 run "$d"
assert_contains "$T_OUT" "2 in the register, 0 mismatches, 0 past their removal date, 0 removal tasks tbd"
t_end

t_begin "a removed flag still read by a client file or set in deploy config fails; values and client reads are listed"
d="$(tmpdir)/removed"; fixture "$d"
mkdir -p "$d/static" "$d/deploy" "$d/config" "$d/tests"
printf 'var f = window.FLAGS || {};\nif (f["old_search"]) { go(); }\nif (f["new_checkout"]) { pay(); }\n' > "$d/static/app.js"
printf 'REGION=eu\nFLAG_OLD_SEARCH=true\nFLAG_NEW_CHECKOUT=false\nFLAG_NEW_CHEKOUT=true\n' > "$d/deploy/eu.env"
printf 'REGION=us\nFLAG_NEW_CHECKOUT=true\n' > "$d/deploy/us.env"
printf 'FLAG_NEW_CHECKOUT=false\n' > "$d/.env.example"
printf 'env:\n  - name: FLAG_KILL_RECOMMENDATIONS\n    value: "false"\n' > "$d/deploy/k8s.yaml"
printf '{"acct_1": {"old_search": false}}\n' > "$d/config/overrides.json"
printf 'def test_x():\n    assert "new_checkout"\n' > "$d/tests/test_flags.py"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: static/app.js:2: reads removed flag old_search"
assert_contains "$T_OUT" "problem: deploy/eu.env:2: sets removed flag old_search"
assert_contains "$T_OUT" "problem: deploy/eu.env:4: sets FLAG_NEW_CHEKOUT, which is not a flag in the module"
assert_contains "$T_OUT" "problem: config/overrides.json:1: names removed flag old_search"
assert_contains "$T_OUT" "values: new_checkout: .env.example:1=false, deploy/eu.env:3=false, deploy/us.env:2=true, unset (default) in deploy/k8s.yaml (differs between deployed environments)"
assert_contains "$T_OUT" "values: kill_recommendations: deploy/k8s.yaml:2=false, unset (default) in deploy/eu.env, deploy/us.env (differs between deployed environments)"
assert_contains "$T_OUT" "client read: static/app.js:3: new_checkout"
assert_not_contains "$T_OUT" "config names: config/overrides.json"
assert_not_contains "$T_OUT" "tests/test_flags.py"
assert_contains "$T_OUT" "1 client reads, 5 config files, 4 problems"
t_end

t_begin "an override map naming an active flag is listed as another value source"
d="$(tmpdir)/override"; fixture "$d"
mkdir -p "$d/config"
printf '{"acct_7": [{"flag": "new_checkout", "on": false}]}\n' > "$d/config/flag_overrides.json"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "config names: config/flag_overrides.json:1: new_checkout"
t_end

t_begin "a module that reads any non-empty value as on makes every false, 0 or off setting a problem"
d="$(tmpdir)/lenient"; fixture "$d"
mkdir -p "$d/deploy"
printf '\nfunc lookup(k string) bool { return os.Getenv(k) != "" }\n' >> "$d/internal/flags/flags.go"
printf 'FLAG_NEW_CHECKOUT=false\nFLAG_KILL_RECOMMENDATIONS=true\n' > "$d/deploy/eu.env"
printf 'data:\n  FLAG_KILL_RECOMMENDATIONS: "off"\n  FLAG_NEW_CHECKOUT: ""\n' > "$d/deploy/shared.yaml"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: deploy/eu.env:1: FLAG_NEW_CHECKOUT=false reads as ON: internal/flags/flags.go:13 treats any non-empty value as on"
assert_contains "$T_OUT" "problem: deploy/shared.yaml:2: FLAG_KILL_RECOMMENDATIONS=off reads as ON"
assert_not_contains "$T_OUT" "deploy/eu.env:2: FLAG_KILL"
assert_not_contains "$T_OUT" "shared.yaml:3: FLAG_NEW_CHECKOUT"
t_end

t_begin "zero flags in both, with sources scanned, is a valid pass"
d="$(tmpdir)/zero"; fixture "$d"
printf 'package flags\n\ntype Flag string\n' > "$d/internal/flags/flags.go"
sed -i.bak -e '/^| new_checkout/d' -e '/^| kill_rec/d' "$d/docs/operations/flags.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "feature-flags: 0 flags in internal/flags/flags.go, 0 in the register"
t_end

t_begin "empty input fails: no module and no register, or no source files"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "no flags module"
assert_contains "$T_OUT" "nothing checked"
mkdir -p "$d/docs/operations"; printf '## Active flags\n\n| Flag | Owner | Target date |\n| --- | --- | --- |\n' > "$d/docs/operations/flags.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 source files scanned"
t_end

t_summary
