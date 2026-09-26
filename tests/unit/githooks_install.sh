#!/usr/bin/env bash
# tests/unit/githooks_install.sh: plugins/bearing/templates/repo/.githooks/install.sh is
# idempotent. A fresh clone gets core.hooksPath=.githooks and the three hooks
# counted. When the value is already set it does not write .git/config at
# all: Claude Code's sandbox mounts that file read-only, and an unconditional
# write failed `make setup` in every scaffolded repository with "could not
# write config file .git/config". A wrong value on an unwritable config still
# fails loudly.
#
# "Unwritable" is a held .git/config.lock, not chmod: git refuses to write
# while the lock exists for every user, while root (the CI images) ignores
# permission bits.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HOOKS="$KIT/plugins/bearing/templates/repo/.githooks"

# clone: a fresh repository holding the committed hooks, not yet installed.
clone() {
  local d
  d="$(tmpdir)"
  (cd "$d" && git init -q -b main . && cp -R "$HOOKS" .githooks) || return 1
  printf '%s' "$d"
}
install() { (cd "$1" && bash .githooks/install.sh); }
lock() { : > "$1/.git/config.lock"; }
unlock() { rm -f "$1/.git/config.lock"; }

t_begin "a fresh clone gets core.hooksPath and three hooks"
d="$(clone)"
assert_exit 0 install "$d"
assert_contains "$T_OUT" "git hooks installed: core.hooksPath=.githooks (3 hooks)"
assert_eq ".githooks" "$(git -C "$d" config core.hooksPath)" "core.hooksPath"
t_end

t_begin "already installed: .git/config is not written, so an unwritable one passes"
d="$(clone)"
install "$d" >/dev/null
lock "$d"
assert_exit 0 install "$d"
assert_contains "$T_OUT" "git hooks installed: core.hooksPath=.githooks (3 hooks)"
unlock "$d"
t_end

t_begin "a wrong value on an unwritable .git/config fails"
d="$(clone)"
git -C "$d" config core.hooksPath elsewhere
lock "$d"
assert_exit 1 install "$d"
assert_contains "$T_OUT" "could not set core.hooksPath=.githooks"
unlock "$d"
assert_eq "elsewhere" "$(git -C "$d" config core.hooksPath)" "value left as found"
t_end

t_summary
