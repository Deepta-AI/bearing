#!/usr/bin/env bash
# tests/unit/config_helper.sh: brg-config answers round-trip in project and
# user scope, keep every other line of bearing.env, validate keys, and need jq
# for project scope.
set -u
. "$(dirname "$0")/../lib/assert.sh"
C="$KIT/plugins/bearing/bin/brg-config"
repo="$(tmpdir)"; cfg="$(tmpdir)"; git -C "$repo" init -q -b main; mkdir -p "$repo/.bearing"
unset BEARING_ENV
run() { ( cd "$repo" && XDG_CONFIG_HOME="$cfg" bash "$C" "$@" ) }
envf="$cfg/bearing/bearing.env"

t_begin "project round trip"
assert_exit 0 run set design.buildPath code
assert_exit 0 run get design.buildPath
assert_eq "code" "$T_OUT"
assert_contains "$(cat "$repo/.bearing/config.json")" '"design.buildPath": "code"'
assert_exit 0 run set other yes
assert_exit 0 run get design.buildPath
assert_eq "code" "$T_OUT" "second key leaves the first"
t_end

t_begin "user round trip replaces"
assert_exit 0 run set update-skip v0.8.0 --user
assert_exit 0 run set update-skip v0.9.0 --user
assert_exit 0 run get update-skip --user
assert_eq "v0.9.0" "$T_OUT"
assert_eq 1 "$(grep -c '^BEARING_UPDATE_SKIP=' "$envf")" "one line"
t_end

t_begin "missing key is empty and a read writes nothing"
fresh="$(tmpdir)"; git -C "$fresh" init -q -b main
assert_exit 0 bash -c "cd '$fresh' && XDG_CONFIG_HOME='$cfg' bash '$C' get nothing.here"
assert_eq "" "$T_OUT"
assert_eq "no" "$([ -e "$fresh/.bearing" ] && echo yes || echo no)" "get creates no .bearing"
assert_exit 0 run get nothing.here --user
assert_eq "" "$T_OUT"
t_end

t_begin "user set keeps every other line and mode 600"
mkdir -p "$cfg/bearing"
printf '# my settings\n\nBEARING_TRACKER=jira\n  # indented comment\nBEARING_PROFILE="strict"   \nBEARING_UPDATE_SKIP=v0.1.0\nOTHER=1\n' > "$envf"
chmod 644 "$envf"
before="$(grep -v '^BEARING_UPDATE_SKIP=' "$envf")"
assert_exit 0 run set update-skip v0.2.0 --user
after="$(grep -v '^BEARING_UPDATE_SKIP=' "$envf")"
assert_eq "$before" "$after" "all other lines identical"
assert_contains "$(cat "$envf")" "BEARING_UPDATE_SKIP=v0.2.0"
assert_file "$envf" 600
assert_exit 0 run set brand-new x --user
assert_exit 0 run get tracker --user
assert_eq "jira" "$T_OUT"
assert_exit 0 run get profile --user
assert_eq "strict" "$T_OUT" "quoted values read back unquoted"
assert_eq "no" "$(ls "$cfg/bearing" | grep -c tmp | grep -q '^0$' && echo no || echo leftover)" "no temp file left"
t_end

t_begin "a value with a comment marker or edge space round trips"
assert_exit 0 run set note "a # b" --user
assert_exit 0 run get note --user
assert_eq "a # b" "$T_OUT"
assert_exit 0 run set pad " x " --user
assert_exit 0 run get pad --user
assert_eq " x " "$T_OUT"
t_end

t_begin "keys outside [A-Za-z0-9._-] are rejected"
assert_exit 2 run set 'a.*|b' v
assert_contains "$T_OUT" "key may hold only"
assert_exit 2 run get 'a b' --user
assert_exit 2 run set 'a"b' v --user
assert_exit 2 run get 'x$(id)'
assert_eq "no" "$(grep -q 'a\.\*' "$repo/.bearing/config.json" && echo yes || echo no)" "nothing written"
t_end

t_begin "usage errors exit 2"
assert_exit 2 run
assert_exit 2 run get
assert_exit 2 run frob key
assert_exit 2 run set onlykey
t_end

t_begin "project scope without jq exits 1 with the message"
nojq="$(minimal_path bash git dirname grep tr tail mkdir chmod mv rm)"
assert_exit 1 bash -c "cd '$repo' && PATH='$nojq' XDG_CONFIG_HOME='$cfg' '$(command -v bash)' '$C' set a b"
assert_contains "$T_OUT" "brg-config: jq required"
assert_exit 0 bash -c "cd '$repo' && PATH='$nojq' XDG_CONFIG_HOME='$cfg' '$(command -v bash)' '$C' set a b --user"
t_end
t_begin "set refuses the auto-push key in every spelling"
printf 'BEARING_TRACKER=none\n' > "$envf"
for k in auto-push auto_push AUTO.PUSH Auto-Push; do
  assert_exit 2 run set "$k" "Shop/Server/ShopApi" --user
  assert_contains "$T_OUT" "BEARING_AUTO_PUSH is set by hand"
  assert_exit 2 run set "$k" on
done
assert_eq "BEARING_TRACKER=none" "$(cat "$envf")" "bearing.env unchanged"
t_end

t_begin "get reads the auto-push key"
printf 'BEARING_AUTO_PUSH="Shop/Server/ShopApi, Shop/Client/ShopWeb"\n' > "$envf"
assert_exit 0 run get auto-push --user
assert_eq "Shop/Server/ShopApi, Shop/Client/ShopWeb" "$T_OUT"
t_end
t_summary
