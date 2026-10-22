#!/usr/bin/env bash
# tests/unit/pin_refresh.sh: bin/pin-refresh.py reports, for every row of
# pinned-packs.txt, whether upstream moved past the pin and which files under
# the pinned path changed; npm and PyPI rows get the registry's latest
# version. It never edits the pin file. Local repositories and registry files
# stand in for GitHub, npm and PyPI.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
g() { git -C "$1" -c user.email=t@example.com -c user.name=t -c commit.gpgsign=false "${@:2}"; }
mk() {  # mk <owner/repo>: a repository with skills/a/SKILL.md and skills/b/SKILL.md
  r="$d/remotes/$1"; mkdir -p "$r/skills/a" "$r/skills/b"; git init -q -b main "$r"
  echo "# a v1" > "$r/skills/a/SKILL.md"; echo "# b v1" > "$r/skills/b/SKILL.md"
  g "$r" add -A; g "$r" commit -q -m v1
}
mk acme/skills; v1="$(git -C "$d/remotes/acme/skills" rev-parse HEAD)"
mk other/pack; o1="$(git -C "$d/remotes/other/pack" rev-parse HEAD)"
# acme moves on: skills/a changes, skills/b does not.
echo "# a v2" > "$d/remotes/acme/skills/skills/a/SKILL.md"; echo ref > "$d/remotes/acme/skills/skills/a/notes.md"
g "$d/remotes/acme/skills" add -A; g "$d/remotes/acme/skills" commit -q -m v2

mkdir -p "$d/npm/left-pad" "$d/pypi/ruff"
echo '{"version": "1.4.0"}' > "$d/npm/left-pad/latest"
echo '{"info": {"version": "0.9.1"}}' > "$d/pypi/ruff/json"

pins="$d/pinned-packs.txt"
cat > "$pins" <<P
# comment lines and blanks are skipped

skill|acme/skills|$v1|skills/a|a|MIT
skill|acme/skills|$v1|skills/b|b|MIT
cli|other/pack|$o1|b|b|MIT
npm|left-pad|1.3.0|tests|left-pad|MIT
pypi|ruff|0.9.1|lint|ruff|MIT
P
before="$(cat "$pins")"
pr() {
  BRG_PIN_GIT_URL="file://$d/remotes/{repo}" BRG_PIN_NPM_URL="file://$d/npm/{pkg}/latest" \
    BRG_PIN_PYPI_URL="file://$d/pypi/{pkg}/json" python3 "$KIT/bin/pin-refresh.py" --pins "$pins" --cache "$d/cache" "$@"
}

t_begin "every pin is checked and counted; behind ones name what changed"
assert_exit 0 pr
assert_contains "$T_OUT" "skill acme/skills a: ${v1:0:7} -> "
assert_contains "$T_OUT" "2 files changed under skills/a (SKILL.md changed)"
assert_contains "$T_OUT" "skill acme/skills b: upstream moved, nothing under skills/b changed"
assert_contains "$T_OUT" "cli other/pack b: current"
assert_contains "$T_OUT" "npm left-pad: 1.3.0 -> 1.4.0"
assert_contains "$T_OUT" "pypi ruff: current"
assert_contains "$T_OUT" "pin-refresh: 5 pins checked, 2 behind, 0 errors"
t_end

t_begin "the pin file is never edited"
assert_eq "$before" "$(cat "$pins")" "pin file"
t_end

t_begin "a cli row matches its skill by name anywhere in the repository"
echo "# b v2" > "$d/remotes/other/pack/skills/b/SKILL.md"; g "$d/remotes/other/pack" commit -q -am v2
assert_exit 0 pr
assert_contains "$T_OUT" "cli other/pack b: ${o1:0:7} -> "
assert_contains "$T_OUT" "1 files changed under b (SKILL.md changed)"
t_end

t_begin "a link under the pinned path at the new commit is named"
ln -s ../../shared "$d/remotes/acme/skills/skills/a/references"; g "$d/remotes/acme/skills" add -A; g "$d/remotes/acme/skills" commit -q -m link
assert_exit 0 pr
assert_contains "$T_OUT" "(links now: skills/a/references; the installer would copy them as links)"
t_end

t_begin "a link inside a cli row's skill folder is named too"
ln -s ../../elsewhere "$d/remotes/other/pack/skills/b/refs"; g "$d/remotes/other/pack" add -A; g "$d/remotes/other/pack" commit -q -m link
assert_exit 0 pr
assert_contains "$T_OUT" "(links now: skills/b/refs; the installer would copy them as links)"
t_end

t_begin "an unreachable upstream is an error, not current"
printf 'skill|gone/repo|%s|skills/a|a|MIT\n' "$v1" >> "$pins"
assert_exit 1 pr
assert_contains "$T_OUT" "skill gone/repo a: error"
assert_contains "$T_OUT" "1 errors"
t_end

t_begin "a pin file with no rows fails"
printf '# only a comment\n' > "$d/empty.txt"
assert_exit 1 python3 "$KIT/bin/pin-refresh.py" --pins "$d/empty.txt" --cache "$d/cache"
assert_contains "$T_OUT" "0 pins"
t_end

t_summary
