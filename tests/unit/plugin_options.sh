#!/usr/bin/env bash
# tests/unit/plugin_options.sh: Bearing's Claude Code plugin settings
# (userConfig). Hooks get them as CLAUDE_PLUGIN_OPTION_<KEY>; the agent's Bash
# gets none, so the SessionStart hook writes a copy that brg-plugin-options
# print reads back. Precedence is the environment, then plugin settings, then
# bearing.env. Only the listed, non-secret keys pass, each value checked on
# the way out of the copy too. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
O="$KIT/plugins/bearing/bin/brg-plugin-options"
copy="$XDG_CONFIG_HOME/bearing-options/options.env"
# The suite may run inside a Claude Code hook: no inherited plugin variables.
for v in $(compgen -e); do case "$v" in (CLAUDE_PLUGIN_OPTION_*|CLAUDE_PLUGIN_ROOT) unset "$v";; esac; done
opts() { env "$@" bash "$O" print; } # opts VAR=value...: print with those options in the environment

t_begin "options from a hook's environment map to BEARING keys"
assert_exit 0 opts CLAUDE_PLUGIN_OPTION_TRACKER=Jira CLAUDE_PLUGIN_OPTION_TRACKER_URL=https://you.atlassian.net \
  CLAUDE_PLUGIN_OPTION_TASK_ID_PREFIX=PROJ CLAUDE_PLUGIN_OPTION_LEARNING=on \
  CLAUDE_PLUGIN_OPTION_NONINTERACTIVE=On CLAUDE_PLUGIN_OPTION_UPDATE_CHECK=off
assert_contains "$T_OUT" "BEARING_TRACKER=jira" "tracker lower-cased"
assert_contains "$T_OUT" "BEARING_TRACKER_URL=https://you.atlassian.net"
assert_contains "$T_OUT" "BEARING_TASK_ID_PREFIX=PROJ"
assert_contains "$T_OUT" "BEARING_LEARNING=on"
assert_contains "$T_OUT" "BEARING_NONINTERACTIVE=1" "on is 1"
assert_contains "$T_OUT" "BEARING_UPDATE_CHECK=off"
t_end

t_begin "surrounding spaces go, and the URL scheme is read in any case"
assert_exit 0 opts "CLAUDE_PLUGIN_OPTION_TRACKER_URL= HTTPS://gitlab.acme.internal " "CLAUDE_PLUGIN_OPTION_TRACKER_PROJECT= acme/api "
assert_contains "$T_OUT" "BEARING_TRACKER_URL=https://gitlab.acme.internal"
assert_contains "$T_OUT" "BEARING_TRACKER_PROJECT=acme/api"
t_end

t_begin "a value its key does not allow is dropped"
assert_exit 0 opts CLAUDE_PLUGIN_OPTION_TRACKER=trello CLAUDE_PLUGIN_OPTION_TRACKER_URL=ftp://x \
  CLAUDE_PLUGIN_OPTION_TASK_ID_PREFIX=proj CLAUDE_PLUGIN_OPTION_TRACKER_PROJECT='a$(id)' \
  CLAUDE_PLUGIN_OPTION_LEARNING=maybe CLAUDE_PLUGIN_OPTION_NONINTERACTIVE=yes \
  "CLAUDE_PLUGIN_OPTION_TRACKER_EMAIL=a@b.c
BEARING_TRACKER_TOKEN=x"
assert_eq "" "$T_OUT" "nothing passes"
assert_exit 0 env CLAUDE_PLUGIN_OPTION_TRACKER=trello CLAUDE_PLUGIN_OPTION_TRACKER_URL=ftp://x bash "$O" rejected
assert_contains "$T_OUT" "tracker: not one of none, jira, gitlab, github, rest"
assert_contains "$T_OUT" "tracker_url: not an http:// or https:// URL"
t_end

t_begin "a rejected setting is kept by name in the copy and named by tracker config and the session"
assert_exit 0 env CLAUDE_PLUGIN_OPTION_TRACKER=gitlab CLAUDE_PLUGIN_OPTION_TRACKER_URL=gitlab.acme.internal bash "$O" write
assert_contains "$T_OUT" "1 plugin setting(s) copied"
assert_contains "$T_OUT" "1 rejected"
assert_exit 0 bash "$O" rejected
assert_contains "$T_OUT" "tracker_url: not an http:// or https:// URL"
assert_exit 0 env BEARING_ENV=/nonexistent bash "$KIT/plugins/bearing/bin/brg-tracker" config
assert_contains "$T_OUT" "plugin setting tracker_url ignored: not an http:// or https:// URL"
assert_exit 1 env BEARING_ENV=/nonexistent bash "$KIT/plugins/bearing/bin/brg-tracker" me
assert_contains "$T_OUT" "not calling gitlab on its default host" "a rejected URL never falls back to gitlab.com"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
assert_exit 0 bash -c "cd '$repo' && env CLAUDE_PLUGIN_ROOT='$KIT/plugins/bearing' CLAUDE_PLUGIN_OPTION_TRACKER_URL=nope bash '$GUARD' session --id s1 --source resume"
assert_contains "$T_OUT" "bearing: plugin setting tracker_url ignored"
rm -f "$copy"
t_end

t_begin "write copies the set options, private, and says how many"
assert_exit 0 env CLAUDE_PLUGIN_OPTION_TRACKER=github CLAUDE_PLUGIN_OPTION_TRACKER_PROJECT=acme/api bash "$O" write
assert_contains "$T_OUT" "2 plugin setting(s) copied"
assert_file "$copy" 600
assert_file "$(dirname "$copy")" 700
assert_exit 0 bash "$O" print
assert_contains "$T_OUT" "BEARING_TRACKER=github" "the agent's Bash reads the copy"
assert_contains "$T_OUT" "BEARING_TRACKER_PROJECT=acme/api"
t_end

t_begin "the copy never passes a secret, the push opt-in or a bad value"
printf 'BEARING_TRACKER=gitlab\nBEARING_TRACKER_TOKEN=leak\nBEARING_AUTO_PUSH=git@evil:x\nBEARING_TRACKER_URL=https://a b\nBEARING_NONINTERACTIVE=1\n' > "$copy"
assert_exit 0 bash "$O" print
assert_contains "$T_OUT" "BEARING_TRACKER=gitlab"
assert_contains "$T_OUT" "BEARING_NONINTERACTIVE=1"
assert_not_contains "$T_OUT" "TOKEN" "no token"
assert_not_contains "$T_OUT" "AUTO_PUSH" "no push opt-in"
assert_not_contains "$T_OUT" "TRACKER_URL" "a URL with a space is dropped"
t_end

t_begin "with no options set, write removes the copy; a linked copy is never read or written"
assert_exit 0 bash "$O" write
assert_contains "$T_OUT" "0 plugin settings set, no copy"
gone=1; [ -e "$copy" ] && gone=0; assert_eq 1 "$gone" "the old copy is gone"
elsewhere="$(tmpdir)"; printf 'BEARING_TRACKER=jira\n' > "$elsewhere/o.env"; ln -s "$elsewhere/o.env" "$copy"
assert_exit 0 bash "$O" print
assert_eq "" "$T_OUT" "a link is not read"
assert_exit 1 env CLAUDE_PLUGIN_OPTION_TRACKER=github bash "$O" write
assert_eq "BEARING_TRACKER=jira" "$(cat "$elsewhere/o.env")" "nor written through"
rm -f "$copy"
env CLAUDE_PLUGIN_OPTION_TRACKER=github bash "$O" write >/dev/null
ln "$copy" "$elsewhere/hard"
assert_exit 0 bash "$O" print
assert_eq "" "$T_OUT" "a copy with a second hard link is not read"
rm -f "$copy" "$elsewhere/hard"
t_end

t_begin "the update check honours the plugin setting with no bearing.env"
assert_exit 0 bash "$KIT/plugins/bearing/bin/brg-config" get update-check --user
assert_eq "" "$T_OUT" "nothing set"
assert_exit 0 env -u BEARING_UPDATE_CHECK CLAUDE_PLUGIN_OPTION_UPDATE_CHECK=off bash "$KIT/plugins/bearing/bin/brg-update-check" --remote /nonexistent --installed 0.1.0
assert_eq "" "$T_OUT" "off: no check, no offer"
calls=0; [ -e "$XDG_CONFIG_HOME/bearing/update-check" ] && calls=1
assert_eq 0 "$calls" "no cache written, so no remote was asked"
t_end

t_begin "precedence: environment, then plugin settings, then bearing.env"
envf="$(tmpdir)/bearing.env"; printf 'BEARING_TRACKER=gitlab\nBEARING_TRACKER_PROJECT=from-file\n' > "$envf"
env CLAUDE_PLUGIN_OPTION_TRACKER=github bash "$O" write >/dev/null
assert_exit 0 env BEARING_ENV="$envf" bash "$KIT/plugins/bearing/bin/brg-tracker" config
assert_contains "$T_OUT" "tracker: github (from plugin settings)" "plugin over file"
assert_contains "$T_OUT" "project: from-file" "the file still fills what the plugin leaves"
assert_contains "$T_OUT" "plugin settings: 1 key(s) in use (BEARING_TRACKER)"
assert_exit 0 env BEARING_ENV="$envf" BEARING_TRACKER=jira bash "$KIT/plugins/bearing/bin/brg-tracker" config
assert_contains "$T_OUT" "tracker: jira (from environment)" "environment over plugin"
rm -f "$copy"
t_end

t_begin "brg-config reads a plugin setting first and warns when one shadows a write"
C="$KIT/plugins/bearing/bin/brg-config"
assert_exit 0 env CLAUDE_PLUGIN_OPTION_LEARNING=off bash "$C" get learning --user
assert_eq "off" "$T_OUT"
assert_exit 0 env CLAUDE_PLUGIN_OPTION_LEARNING=off bash "$C" set learning on --user
assert_contains "$T_OUT" "also set in Claude Code's plugin settings (off), which wins"
assert_exit 0 bash "$C" get learning --user
assert_eq "on" "$T_OUT" "the file holds what set wrote"
t_end

t_begin "the session hook writes the copy under Claude Code only"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
R="$KIT/plugins/bearing"
session() { ( cd "$repo" && env "$@" bash "$GUARD" session --id s1 --source resume ) >/dev/null 2>&1; }
there() { [ -f "$copy" ] && echo yes || echo no; }
session CLAUDE_PLUGIN_OPTION_TRACKER=rest
assert_eq no "$(there)" "another harness's session writes nothing"
session CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PLUGIN_OPTION_TRACKER=rest
assert_eq yes "$(there)" "a Claude Code session writes it"
assert_contains "$(cat "$copy")" "BEARING_TRACKER=rest"
session
assert_eq yes "$(there)" "another harness's session leaves it"
session CLAUDE_PLUGIN_ROOT="$R"
assert_eq no "$(there)" "a Claude Code session with no settings clears it"
t_end

t_begin "the repository template keeps the agent from writing the copy"
S="$KIT/plugins/bearing/templates/repo/.claude/settings.json"
assert_contains "$(jq -r '.permissions.deny[]' "$S")" "Edit(~/.config/bearing-options/**)"
assert_contains "$(jq -r '.permissions.deny[]' "$S")" "Write(~/.config/bearing-options/**)"
assert_contains "$(jq -r '.sandbox.filesystem.denyWrite[]' "$S")" "~/.config/bearing-options"
assert_not_contains "$(jq -r '.sandbox.filesystem.denyRead[]' "$S")" "~/.config/bearing-options" "the agent's Bash can read it"
t_end

t_begin "the manifest's options are the script's, and none is a secret"
M="$KIT/plugins/bearing/.claude-plugin/plugin.json"
manifest="$(jq -r '.userConfig | keys[] | ascii_upcase' "$M" | sort | tr '\n' ' ')"
script="$(sed -n "/^MAP='/,/'\$/p" "$O" | sed -e "s/^MAP='//" -e "s/'\$//" | cut -d'|' -f1 | sort | tr '\n' ' ')"
assert_eq "$script" "$manifest" "same options"
assert_eq 8 "$(jq '.userConfig | length' "$M")" "eight options"
assert_eq "" "$(jq -r '.userConfig | to_entries[] | select(.value.sensitive == true or (.key | test("token|password|push"))) | .key' "$M")" "no secret, no push"
assert_eq "" "$(jq -r '.userConfig | to_entries[] | select(has("value") and (.value | has("default"))) | .key' "$M")" "no default overrides bearing.env"
t_end

t_summary
