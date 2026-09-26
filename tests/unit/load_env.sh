#!/usr/bin/env bash
# tests/unit/load_env.sh: the KEY=value parser that reads
# ~/.config/bearing/bearing.env. One copy of it lives in each script that
# needs it (brg-tracker, brg-jira, brg-gitlab, brg-github, brg-scaffold,
# brg-adopt, and load_kv in brg-rest), so the test first proves the copies are
# identical, then exercises the parser extracted from brg-tracker directly
# (quoted values, an inline # comment, a # kept inside quotes, CRLF lines, no
# trailing newline, environment precedence, an absent file, a value holding
# =), then the same cases end to end through brg-tracker config and the
# doctor's own BEARING_TRACKER read. The developer's real env file is never
# opened: every run points BEARING_ENV at a file under a temporary directory.
set -u
. "$(dirname "$0")/../lib/assert.sh"

work="$(tmpdir)"

# parser_of <script> [function]: the function text, normalised so the brg-rest
# variant (load_kv FILE) compares equal to the ENV_FILE variant.
parser_of() {
  sed -n "/^${2:-load_env}() {/,/^}/p" "$KIT/plugins/bearing/bin/$1" \
    | sed -e "s/^${2:-load_env}() {/load_env() {/" -e 's/"\$1"/"$ENV_FILE"/g'
}

# ---- one parser, seven copies
t_begin "every script carries the same parser"
ref="$(parser_of brg-tracker)"
nlines="$(printf '%s\n' "$ref" | wc -l | tr -d ' ')"
assert_eq 1 "$([ "$nlines" -ge 10 ] && echo 1)" "brg-tracker load_env extracted ($nlines lines)"
copies=0
for s in brg-jira brg-gitlab brg-github brg-scaffold brg-adopt brg-harness; do
  copies=$((copies+1))
  assert_eq "$ref" "$(parser_of "$s")" "load_env in $s matches brg-tracker"
done
copies=$((copies+1))
assert_eq "$ref" "$(parser_of brg-rest load_kv)" "load_kv in brg-rest matches brg-tracker"
t_end

# ---- the parser itself, in a clean bash with only the function loaded
printf '%s\n' "$ref" > "$work/parser.sh"
# parse <env file> <var>...: run load_env on the file in a fresh bash and
# print each variable's value on its own line ("<unset>" when not exported).
parse() {
  local f="$1"; shift
  bash -c '. "$1"; ENV_FILE="$2"; shift 2; load_env; for v in "$@"; do if [ -n "${!v+x}" ]; then printf "%s\n" "${!v}"; else echo "<unset>"; fi; done' _ "$work/parser.sh" "$f" "$@"
}

t_begin "quoted values, inline comments, a # inside quotes"
cat > "$work/a.env" <<'EOF'
# Bearing user configuration
BEARING_TRACKER=jira            # none | jira | gitlab
BEARING_TRACKER_URL="https://you.atlassian.net/#/board"   # a # inside quotes stays
BEARING_TRACKER_PROJECT='PROJ # not a comment'
  BEARING_TRACKER_EMAIL = probe@example.com
BEARING_TRACKER_TOKEN=abc123 #trailing
EMPTY=
NOEQUALS
lower_case=ignored
BAD-KEY=ignored
EOF
assert_eq "jira" "$(parse "$work/a.env" BEARING_TRACKER)" "inline comment dropped from an unquoted value"
assert_eq "https://you.atlassian.net/#/board" "$(parse "$work/a.env" BEARING_TRACKER_URL)" "# kept inside double quotes"
assert_eq "PROJ # not a comment" "$(parse "$work/a.env" BEARING_TRACKER_PROJECT)" "# kept inside single quotes"
assert_eq "probe@example.com" "$(parse "$work/a.env" BEARING_TRACKER_EMAIL)" "spaces around = and leading indent"
assert_eq "abc123" "$(parse "$work/a.env" BEARING_TRACKER_TOKEN)" "#comment without a space before it"
assert_eq "" "$(parse "$work/a.env" EMPTY)" "empty value is set to empty"
assert_eq "<unset>" "$(parse "$work/a.env" NOEQUALS)" "a line without = is ignored"
assert_eq "<unset>" "$(parse "$work/a.env" lower_case)" "lower-case keys are ignored"
t_end

t_begin "CRLF line endings and no trailing newline"
printf 'BEARING_TRACKER=gitlab\r\nBEARING_TRACKER_URL="https://gitlab.example.com"\r\nBEARING_TRACKER_PROJECT=group/repo   \r\n' > "$work/crlf.env"
assert_eq "gitlab" "$(parse "$work/crlf.env" BEARING_TRACKER)" "CR stripped from an unquoted value"
assert_eq "https://gitlab.example.com" "$(parse "$work/crlf.env" BEARING_TRACKER_URL)" "CR after a closing quote dropped"
assert_eq "group/repo" "$(parse "$work/crlf.env" BEARING_TRACKER_PROJECT)" "trailing spaces and CR trimmed"
printf 'BEARING_TRACKER=github\nBEARING_TRACKER_PROJECT=acme/probe' > "$work/nonl.env"
assert_eq "acme/probe" "$(parse "$work/nonl.env" BEARING_TRACKER_PROJECT)" "last line without a newline is read"
assert_eq "github" "$(parse "$work/nonl.env" BEARING_TRACKER)"
t_end

t_begin "a value holding = and the environment winning over the file"
printf 'BEARING_TRACKER_URL=https://host/api?a=1&b=2\nBEARING_TRACKER_TOKEN="x=y=z"\nBEARING_TRACKER=jira\n' > "$work/eq.env"
assert_eq "https://host/api?a=1&b=2" "$(parse "$work/eq.env" BEARING_TRACKER_URL)" "only the first = splits"
assert_eq "x=y=z" "$(parse "$work/eq.env" BEARING_TRACKER_TOKEN)" "quoted value with = kept whole"
assert_eq "none" "$(BEARING_TRACKER=none parse "$work/eq.env" BEARING_TRACKER)" "an exported variable is never overridden"
assert_eq "" "$(BEARING_TRACKER='' parse "$work/eq.env" BEARING_TRACKER)" "an exported empty variable still wins"
assert_eq "jira" "$(parse "$work/eq.env" BEARING_TRACKER)" "the file supplies it when the environment does not"
t_end

t_begin "an absent file sets nothing and does not fail"
assert_eq "<unset>" "$(parse "$work/does-not-exist.env" BEARING_TRACKER)"
assert_exit 0 bash -c '. "$1"; ENV_FILE="$2"; load_env' _ "$work/parser.sh" "$work/does-not-exist.env"
t_end

# ---- end to end through brg-tracker config (prints names, never secrets)
TR="$KIT/plugins/bearing/bin/brg-tracker"
t_begin "brg-tracker config reads the file the same way"
assert_exit 0 env -u BEARING_TRACKER -u BEARING_TRACKER_URL -u BEARING_TRACKER_PROJECT -u BEARING_TRACKER_EMAIL -u BEARING_TRACKER_TOKEN BEARING_ENV="$work/a.env" bash "$TR" config
assert_contains "$T_OUT" "tracker: jira (from $work/a.env)"
assert_contains "$T_OUT" "url: https://you.atlassian.net/#/board"
assert_contains "$T_OUT" "project: PROJ # not a comment"
assert_contains "$T_OUT" "email: probe@example.com"
assert_contains "$T_OUT" "auth: token set"
assert_not_contains "$T_OUT" "abc123" "the token is never printed"
assert_exit 0 env -u BEARING_TRACKER -u BEARING_TRACKER_URL -u BEARING_TRACKER_PROJECT BEARING_ENV="$work/crlf.env" bash "$TR" config
assert_contains "$T_OUT" "tracker: gitlab (from $work/crlf.env)"
assert_contains "$T_OUT" "project: group/repo"
assert_exit 0 env BEARING_TRACKER=none BEARING_ENV="$work/a.env" bash "$TR" config
assert_contains "$T_OUT" "tracker: none (from environment)"
assert_exit 0 env -u BEARING_TRACKER BEARING_ENV="$work/does-not-exist.env" bash "$TR" config
assert_contains "$T_OUT" "tracker: none (from default)"
assert_contains "$T_OUT" "env file: $work/does-not-exist.env (absent)"
t_end

# ---- brg-doctor's own read of BEARING_TRACKER from the file (fake HOME)
t_begin "brg-doctor reads BEARING_TRACKER from a fake HOME"
fh="$(tmpdir)"
mkdir -p "$fh/.config/bearing"
printf 'BEARING_TRACKER=jira            # none | jira | gitlab\nBEARING_TRACKER_TOKEN="abc123"\n' > "$fh/.config/bearing/bearing.env"
chmod 600 "$fh/.config/bearing/bearing.env"
docpath="$(minimal_path bash git make jq python3 awk sed grep head tail cut tr stat ls cat basename dirname)"
t_run env -u XDG_CONFIG_HOME HOME="$fh" PATH="$docpath" bash "$KIT/plugins/bearing/bin/brg-doctor"
assert_contains "$T_OUT" "bearing.env present (BEARING_TRACKER=jira; none is valid)"
assert_not_contains "$T_OUT" "abc123" "doctor never prints the token"
assert_not_contains "$T_OUT" "mode is 600" "mode 600 raises no note"
t_end

echo "load_env: $copies parser copies compared, 5 env files parsed"
t_summary
