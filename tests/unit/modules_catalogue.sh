#!/usr/bin/env bash
# tests/unit/modules_catalogue.sh: brg-modules, the helper behind
# bearing:modules. The catalogue url is configuration with no default; without
# it, or without access, every command says "module catalogue not available"
# and exits 3, and drift reports "skipped", never a pass. A local git
# repository stands in for the catalogue. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
M="$KIT/plugins/bearing/bin/brg-modules"
BEARING_ENV="$(tmpdir)/bearing.env"; export BEARING_ENV   # no user file: only the environment counts
for v in $(compgen -e); do case "$v" in (CLAUDE_PLUGIN_OPTION_*|BEARING_MODULES_REPO) unset "$v";; esac; done
XDG_CONFIG_HOME="$(tmpdir)"; export XDG_CONFIG_HOME
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

cat_repo="$(tmpdir)"
git -C "$cat_repo" init -q -b main
cat > "$cat_repo/catalog.yaml" <<'EOF'
# test catalogue
modules:
  - name: base
    version: 0.1.0
    status: next
    stacks: [go, python]
    licence: green
  - name: mailer
    version: 1.2.0
    status: stable
    stacks: [python]
EOF
git -C "$cat_repo" add -A && git -C "$cat_repo" commit -qm one && git -C "$cat_repo" tag v0.1.0
git -C "$cat_repo" commit -q --allow-empty -m two && git -C "$cat_repo" tag v0.10.0
git -C "$cat_repo" commit -q --allow-empty -m three && git -C "$cat_repo" tag v0.9.0

product="$(tmpdir)"
mkdir -p "$product/.bearing/modules"

t_begin "no catalogue configured: every command says so and exits 3"
for c in access latest list "check base go"; do
  # shellcheck disable=SC2086
  assert_exit 3 bash "$M" $c
  assert_contains "$T_OUT" "module catalogue not available, building from guidance" "$c"
done
t_end

t_begin "a url git would read as an option or a transport helper is refused"
assert_exit 2 env BEARING_MODULES_REPO=--upload-pack=touch bash "$M" access
assert_contains "$T_OUT" "not a git url"
assert_exit 2 env "BEARING_MODULES_REPO=ext::sh -c id" bash "$M" access
t_end

t_begin "no access: the unavailable line, exit 3"
assert_exit 3 env BEARING_MODULES_REPO="$cat_repo/missing" bash "$M" access
assert_contains "$T_OUT" "module catalogue not available, building from guidance (git ls-remote failed"
t_end

export BEARING_MODULES_REPO="$cat_repo"

t_begin "access and the newest tag by version, not by name"
assert_exit 0 bash "$M" access
assert_contains "$T_OUT" "access: ok, 3 release tags"
assert_exit 0 bash "$M" latest
assert_eq "v0.10.0" "$T_OUT" "v0.10.0 is newer than v0.9.0"
t_end

t_begin "check: listed for the stack, warns on next, refuses the wrong stack and an unknown module"
assert_exit 0 bash "$M" check base go
assert_contains "$T_OUT" "check: base for go, version 0.1.0, status next, catalogue v0.10.0"
assert_contains "$T_OUT" "warning: base is status next"
assert_exit 0 bash "$M" check mailer python
assert_not_contains "$T_OUT" "warning"
assert_exit 4 bash "$M" check mailer go
assert_contains "$T_OUT" "not for stack go"
assert_exit 4 bash "$M" check billing go
assert_contains "$T_OUT" "billing is not in the catalogue"
t_end

t_begin "drift on an empty install fails and says nothing was checked"
assert_exit 1 bash "$M" drift "$product"
assert_contains "$T_OUT" "drift: 0 modules installed"
t_end

printf '_commit: v0.10.0\n_src_path: %s\nmodule: base\nstack: go\n' "$cat_repo" > "$product/.bearing/modules/base.yml"
printf "_commit: 'v0.1.0'\n_src_path: %s\nmodule: mailer\nstack: python\n" "$cat_repo" > "$product/.bearing/modules/mailer.yml"

t_begin "list shows the catalogue and what is installed"
assert_exit 0 bash "$M" list "$product"
assert_contains "$T_OUT" "at v0.10.0, 2 modules"
assert_contains "$T_OUT" "mailer"
assert_contains "$T_OUT" "installed here: 2"
assert_contains "$T_OUT" "_commit v0.1.0" "a quoted answer is read unquoted"
t_end

t_begin "drift counts what it checked and fails on a module behind"
assert_exit 1 bash "$M" drift "$product"
assert_contains "$T_OUT" "base: current (v0.10.0)"
assert_contains "$T_OUT" "mailer: behind (v0.1.0, newest v0.10.0)"
assert_contains "$T_OUT" "drift: 2 modules checked against v0.10.0, 1 behind"
t_end

t_begin "drift without access is skipped with the count, never a pass"
assert_exit 3 env BEARING_MODULES_REPO="$cat_repo/missing" bash "$M" drift "$product"
assert_eq "skipped: no catalogue access (2 modules not checked)" "$T_OUT"
assert_exit 3 env -u BEARING_MODULES_REPO bash "$M" drift "$product"
assert_contains "$T_OUT" "skipped: no catalogue access (2 modules not checked)"
t_end

t_summary
