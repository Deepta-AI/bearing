#!/usr/bin/env bash
# tests/integration/doctor_matrix.sh: plugins/bearing/bin/brg-doctor inside a scaffolded
# repository, with a fake HOME (no XDG_CONFIG_HOME) and a PATH of coreutils
# plus a stub claude that prints a version and a plugin list, so the machine
# section passes deterministically and the repository section is what varies.
# The matrix: CI on GitLab files, on GitHub files, on both, on neither
# (MISSING, exit 1); the vendored .bearing/bin/brg-guard with a matching stamp
# (ok) and a stale one (MISSING); the final "brg-doctor: N checks, M missing"
# line must equal the ok and MISSING lines counted, and the exit code must be
# 1 exactly when M > 0. Also: a .yaml workflow counts as CI; a core.hooksPath
# of .husky passes only when its three hooks chain .githooks/ with their
# arguments, keep its exit status and are executable; a hook committed 100644
# or not executable is MISSING; make setup calling a missing script is
# MISSING; a lower-case pull_request_template.md counts; a CI with no make and
# a .gitignore that swallows .claude/rules/ are MISSING; Superpowers and
# gstack are optional unless BEARING_PROFILE is standard or full. The developer's
# real env file is never read: every HOME is a fake one.
set -u
. "$(dirname "$0")/../lib/assert.sh"
DOCTOR="$KIT/plugins/bearing/bin/brg-doctor"
VERSION="$(tr -d '[:space:]' < "$KIT/VERSION")"
TOOLFREE="$(minimal_path bash sh git python3 make jq sed grep find cut sort uniq wc tr mktemp mv cp rm mkdir chmod ls cat basename dirname head tail stat touch env date awk cmp diff)"

# The fake machine: stub claude beside the coreutils, CLAUDE.md and gstack
# present under HOME so every machine check passes.
fh="$(tmpdir)"
mkdir -p "$fh/.claude/skills/gstack"
printf 'personal notes\n' > "$fh/.claude/CLAUDE.md"
printf '9.9.9\n' > "$fh/.claude/skills/gstack/VERSION"
cat > "$TOOLFREE/claude" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo "2.1.0 (Claude Code)";;
  plugin) echo "bearing@bearing 0.1.0"; echo "bearing-backend@bearing 0.1.0"; echo "superpowers@claude-plugins-official 4.0.0";;
esac
exit 0
EOF
chmod +x "$TOOLFREE/claude"

doctor_in() { local d="$1"; (cd "$d" && env -u XDG_CONFIG_HOME -u BEARING_PROFILE HOME="$fh" PATH="$TOOLFREE" bash "$DOCTOR"); }
count_line() { printf '%s\n' "$1" | grep -c "^$2" || true; }
# assert_tally <output> <missing>: the summary line agrees with the ok and
# MISSING lines above it and names the expected missing count.
assert_tally() {
  local ok miss
  ok="$(count_line "$1" 'ok ')"; miss="$(count_line "$1" 'MISSING ')"
  assert_contains "$1" "brg-doctor: $((ok+miss)) checks, $miss missing, "
  assert_eq "$2" "$miss" "missing count"
  assert_eq 1 "$([ "$ok" -gt 10 ] && echo 1)" "the machine and repository sections both passed checks ($ok ok)"
}
runs=0

base="$(tmpdir)/probe-doc"
t_begin "scaffold the repository under test"
assert_exit 0 env -u BEARING_TRACKER -u BEARING_GIT_HOST PATH="$TOOLFREE" BEARING_ENV=/nonexistent bash "$KIT/plugins/bearing/bin/brg-scaffold" go-api ProbeDoc --dir "$base" --host both
t_end

t_begin "both hosts: every check ok, exit 0"
assert_exit 0 doctor_in "$base"; runs=$((runs+1))
assert_contains "$T_OUT" "brg-doctor (kit $VERSION)"
assert_contains "$T_OUT" "ok        claude 2.1.0 (Claude Code)"
assert_contains "$T_OUT" "ok        plugin Bearing installed"
assert_contains "$T_OUT" "ok        plugin bearing-backend installed"
assert_contains "$T_OUT" "optional  plugin bearing-apps not installed; its stack skills and templates are unavailable (claude plugin install bearing-apps@bearing)"
assert_contains "$T_OUT" "ok        plugin superpowers installed"
assert_contains "$T_OUT" "ok        gstack 9.9.9"
assert_contains "$T_OUT" "optional  bearing.env missing"
assert_contains "$T_OUT" "## repository probe-doc"
assert_contains "$T_OUT" "ok        CI present (.gitlab-ci.yml, .github/workflows/ci.yml)"
assert_contains "$T_OUT" "ok        change template present (.gitlab/merge_request_templates/Default.md, .github/PULL_REQUEST_TEMPLATE.md)"
assert_contains "$T_OUT" "ok        core.hooksPath=.githooks"
assert_contains "$T_OUT" "ok        3 git hooks present"
assert_contains "$T_OUT" "ok        make check target"
assert_contains "$T_OUT" "skipped   no vendored .bearing/bin/brg-guard"
assert_tally "$T_OUT" 0
t_end

t_begin "GitLab files only: ok"
gl="$(tmpdir)/probe-gl"; cp -R "$base" "$gl"; rm -rf "$gl/.github"
assert_exit 0 doctor_in "$gl"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        CI present (.gitlab-ci.yml)"
assert_contains "$T_OUT" "ok        change template present (.gitlab/merge_request_templates/Default.md)"
assert_tally "$T_OUT" 0
t_end

t_begin "a .github/workflows/*.yaml workflow counts as CI"
ya="$(tmpdir)/probe-yaml"; cp -R "$base" "$ya"; rm -rf "$ya/.gitlab-ci.yml" "$ya/.gitlab"
mv "$ya/.github/workflows/ci.yml" "$ya/.github/workflows/build.yaml"
assert_exit 0 doctor_in "$ya"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        CI present (.github/workflows/build.yaml)"
assert_tally "$T_OUT" 0
t_end

t_begin "core.hooksPath elsewhere: chained passes, unchained is MISSING"
hk="$(tmpdir)/probe-husky"; cp -R "$base" "$hk"; mkdir -p "$hk/.husky"
git -C "$hk" config core.hooksPath .husky
for h in commit-msg pre-commit; do printf '#!/bin/sh\n.githooks/%s "$@" || exit $?\n' "$h" > "$hk/.husky/$h"; chmod +x "$hk/.husky/$h"; done
assert_exit 1 doctor_in "$hk"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   core.hooksPath=.husky and 2 of 3 of its hooks call .githooks/<hook>"
assert_tally "$T_OUT" 1
printf '#!/bin/sh\n.githooks/pre-push "$@" || exit $?\n' > "$hk/.husky/pre-push"
assert_exit 1 doctor_in "$hk"; runs=$((runs+1))
assert_contains "$T_OUT" "pre-push is not executable" "git skips a non-executable husky hook"
chmod +x "$hk/.husky/pre-push"
assert_exit 0 doctor_in "$hk"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        core.hooksPath=.husky, its 3 hooks chain .githooks/"
assert_tally "$T_OUT" 0
printf '#!/bin/sh\n.githooks/commit-msg "$@" || true\n' > "$hk/.husky/commit-msg"
assert_exit 1 doctor_in "$hk"; runs=$((runs+1))
assert_contains "$T_OUT" "commit-msg calls it but discards its exit status" "|| true makes the chain advisory"
assert_tally "$T_OUT" 1
printf '#!/bin/sh\n.githooks/commit-msg || exit $?\n' > "$hk/.husky/commit-msg"
assert_exit 1 doctor_in "$hk"; runs=$((runs+1))
assert_contains "$T_OUT" "commit-msg calls it without passing its arguments"
t_end

t_begin "a hook git will skip: committed 100644, or not executable here"
hm="$(tmpdir)/probe-mode"; cp -R "$base" "$hm"
git -C "$hm" add .githooks
git -C "$hm" update-index --chmod=-x .githooks/pre-push
assert_exit 1 doctor_in "$hm"; runs=$((runs+1))
assert_contains "$T_OUT" "pre-push committed as 100644 (git update-index --chmod=+x .githooks/pre-push, then commit)"
assert_tally "$T_OUT" 1
git -C "$hm" update-index --chmod=+x .githooks/pre-push; chmod -x "$hm/.githooks/pre-push"
assert_exit 1 doctor_in "$hm"; runs=$((runs+1))
assert_contains "$T_OUT" "pre-push not executable in this clone (chmod +x .githooks/pre-push)"
assert_tally "$T_OUT" 1
t_end

t_begin "make setup: a missing script and an ignored error are MISSING"
ms="$(tmpdir)/probe-setup"; cp -R "$base" "$ms"
awk '/^setup:/ && !d { print "setup: ## hooks"; print "\t-bash scripts/install-hooks.sh"; print "\t@echo hooks installed"; print ""; print "setup-old:"; d=1; next } { print }' "$ms/Makefile" > "$ms/Makefile.new" && mv "$ms/Makefile.new" "$ms/Makefile"
assert_exit 1 doctor_in "$ms"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   make setup calls scripts/install-hooks.sh, which does not exist (and 1 recipe line(s) ignore errors)"
assert_tally "$T_OUT" 1
t_end

t_begin "a lower-case pull_request_template.md counts; a CI without make is MISSING"
lc="$(tmpdir)/probe-lc"; cp -R "$base" "$lc"; rm -rf "$lc/.gitlab-ci.yml" "$lc/.gitlab"
mv "$lc/.github/PULL_REQUEST_TEMPLATE.md" "$lc/.github/pull_request_template.md"
assert_exit 0 doctor_in "$lc"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        change template present (.github/pull_request_template.md)"
printf 'on: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npm test\n' > "$lc/.github/workflows/ci.yml"
assert_exit 1 doctor_in "$lc"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   CI never runs make, so make check is not enforced in CI"
assert_tally "$T_OUT" 1
printf '.claude/*\n!.claude/settings.json\n' >> "$lc/.gitignore"
assert_exit 1 doctor_in "$lc"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   .gitignore ignores .claude/rules/"
assert_tally "$T_OUT" 2
t_end

t_begin "GitHub files only: ok"
gh="$(tmpdir)/probe-gh"; cp -R "$base" "$gh"; rm -rf "$gh/.gitlab-ci.yml" "$gh/.gitlab"
assert_exit 0 doctor_in "$gh"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        CI present (.github/workflows/ci.yml)"
assert_contains "$T_OUT" "ok        change template present (.github/PULL_REQUEST_TEMPLATE.md)"
assert_tally "$T_OUT" 0
t_end

t_begin "neither host: CI and template MISSING, exit 1"
none="$(tmpdir)/probe-none"; cp -R "$base" "$none"; rm -rf "$none/.gitlab-ci.yml" "$none/.gitlab" "$none/.github"
assert_exit 1 doctor_in "$none"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   CI missing: no .gitlab-ci.yml and no .github/workflows/*.yml or *.yaml (ci-pipeline)"
assert_contains "$T_OUT" "MISSING   MR/PR template missing: no .gitlab/merge_request_templates/*.md and no pull_request_template.md (any case) in .github/, docs/ or the root (onboard-repo)"
assert_tally "$T_OUT" 2
t_end

t_begin "vendored brg-guard: matching stamp ok, stale stamp MISSING"
mkdir -p "$base/.bearing/bin"
printf '#!/usr/bin/env bash\nBEARING_GUARD_VERSION="%s"\nexit 0\n' "$VERSION" > "$base/.bearing/bin/brg-guard"
assert_exit 0 doctor_in "$base"; runs=$((runs+1))
assert_contains "$T_OUT" "ok        .bearing/bin/brg-guard version $VERSION matches the kit"
assert_tally "$T_OUT" 0
printf '#!/usr/bin/env bash\nBEARING_GUARD_VERSION="0.0.1"\nexit 0\n' > "$base/.bearing/bin/brg-guard"
assert_exit 1 doctor_in "$base"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   .bearing/bin/brg-guard version 0.0.1 differs from kit $VERSION; run harness-setup again"
assert_tally "$T_OUT" 1
printf '#!/usr/bin/env bash\nexit 0\n' > "$base/.bearing/bin/brg-guard"
assert_exit 1 doctor_in "$base"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   .bearing/bin/brg-guard version unreadable differs from kit $VERSION"
assert_tally "$T_OUT" 1
rm -rf "$base/.bearing"
t_end

t_begin "a broken CLAUDE.md and no hooksPath add up"
printf '# no import\n__STACK__\n' > "$base/CLAUDE.md"
git -C "$base" config --unset core.hooksPath
assert_exit 1 doctor_in "$base"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   CLAUDE.md first line is not @AGENTS.md"
assert_contains "$T_OUT" "MISSING   CLAUDE.md snapshot has unfilled placeholders"
assert_contains "$T_OUT" "MISSING   core.hooksPath not set (bash .githooks/install.sh)"
assert_tally "$T_OUT" 3
t_end

t_begin "a bare machine: every required machine check MISSING, packs optional, one summary line"
bare="$(tmpdir)"
barepath="$(minimal_path bash sh git make jq python3 sed grep cut sort uniq wc tr ls cat basename dirname head tail stat awk)"
assert_exit 1 env -u XDG_CONFIG_HOME -u BEARING_PROFILE HOME="$bare" PATH="$barepath" bash "$DOCTOR"; runs=$((runs+1))
assert_contains "$T_OUT" "MISSING   claude CLI not on PATH"
assert_contains "$T_OUT" "MISSING   plugin Bearing not installed (claude plugin install bearing@bearing, or bash install.sh from the Bearing checkout)"
assert_contains "$T_OUT" "optional  gstack not installed (see docs/INSTALL.md); optional for profile unset"
assert_contains "$T_OUT" "MISSING   ~/.claude/CLAUDE.md missing"
assert_eq 1 "$(count_line "$T_OUT" 'brg-doctor: ')" "one summary line"
miss="$(count_line "$T_OUT" 'MISSING ')"; ok="$(count_line "$T_OUT" 'ok ')"
assert_contains "$T_OUT" "brg-doctor: $((ok+miss)) checks, $miss missing, "
assert_eq 1 "$([ "$miss" -ge 3 ] && echo 1)" "at least claude, Bearing and CLAUDE.md missing ($miss)"
t_end

t_begin "the packs follow BEARING_PROFILE: minimal optional, standard and full required"
# A machine with claude, Bearing and CLAUDE.md but neither Superpowers nor
# gstack, as install.sh --profile minimal leaves it.
mh="$(tmpdir)"; mkdir -p "$mh/.claude" "$mh/.config/bearing"; printf 'notes\n' > "$mh/.claude/CLAUDE.md"
mp="$(minimal_path bash sh git make jq python3 sed grep cut sort uniq wc tr ls cat basename dirname head tail stat awk)"
cat > "$mp/claude" <<'EOF'
#!/bin/sh
case "$1" in --version) echo "2.1.0 (Claude Code)";; plugin) echo "bearing@bearing 0.1.0";; esac
exit 0
EOF
chmod +x "$mp/claude"
machine() { (cd "$mh" && env -u XDG_CONFIG_HOME -u BEARING_PROFILE HOME="$mh" PATH="$mp" "$@" bash "$DOCTOR"); }
# machine_tally <output> <missing>: machine section only, so fewer ok lines.
machine_tally() {
  local ok miss
  ok="$(count_line "$1" 'ok ')"; miss="$(count_line "$1" 'MISSING ')"
  assert_contains "$1" "brg-doctor: $((ok+miss)) checks, $miss missing, "
  assert_eq "$2" "$miss" "missing count"
  assert_eq 1 "$([ "$ok" -ge 5 ] && echo 1)" "machine checks passed ($ok ok)"
}
printf 'BEARING_TRACKER=none\nBEARING_PROFILE=minimal    # minimal | standard | full\n' > "$mh/.config/bearing/bearing.env"; chmod 600 "$mh/.config/bearing/bearing.env"
assert_exit 0 machine; runs=$((runs+1))
assert_contains "$T_OUT" "profile: minimal (bearing.env;"
assert_contains "$T_OUT" "optional  superpowers not installed (claude plugin install superpowers@claude-plugins-official); optional for profile minimal"
assert_contains "$T_OUT" "optional  gstack not installed (see docs/INSTALL.md); optional for profile minimal"
machine_tally "$T_OUT" 0
printf 'BEARING_PROFILE="standard"\n' > "$mh/.config/bearing/bearing.env"
assert_exit 1 machine; runs=$((runs+1))
assert_contains "$T_OUT" "profile: standard (bearing.env;"
assert_contains "$T_OUT" "MISSING   superpowers not installed"
assert_contains "$T_OUT" "MISSING   gstack not installed"
machine_tally "$T_OUT" 2
assert_exit 1 machine BEARING_PROFILE=full; runs=$((runs+1))
assert_contains "$T_OUT" "profile: full (environment;"
machine_tally "$T_OUT" 2
assert_exit 0 machine BEARING_PROFILE=minimal; runs=$((runs+1))
assert_contains "$T_OUT" "profile: minimal (environment;" "the environment wins over the file"
machine_tally "$T_OUT" 0
t_end

echo "doctor_matrix: $runs brg-doctor runs over 10 repository states and 3 profiles"
t_summary
