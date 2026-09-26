#!/usr/bin/env bash
# tests/contract/tracker_fake_server.sh: plugins/bearing/bin/brg-tracker against
# tests/contract/fake_tracker.py, one python3 HTTP stub that answers the URL
# shapes of Jira, GitLab, GitHub and the REST tracker protocol and logs every request
# line and header. For each BEARING_TRACKER the same ten commands run (config,
# me, get, list, create, update, comment, link, close, trace) and must exit 0
# with the adapter's output shape (link: issue-link on Jira, GitLab and
# rest; link: comment on GitHub). The token must never reach stdout
# or stderr, and the server log must show it arrived the right way (Jira
# basic auth, GitLab PRIVATE-TOKEN, GitHub and rest bearer). A
# second stub instance sleeps 35 s per request: one call at it must fail on
# one line within 45 s, which is the adapters' --max-time 30 at work. Then
# BEARING_TRACKER=none (tests/contract/tracker_none folded in here): reads exit 0
# with the skip note, writes exit 3. The developer's env file and cached
# token are never read: BEARING_ENV, XDG_CONFIG_HOME and HOME
# all point at empty temporary directories.
#
# Then, per adapter, against the stateful fake: a create and a comment whose
# first POST is applied and answered 502 leave exactly one item (the retry
# searched for its marker and did not re-post), while a POST refused with 502
# before it applied is sent again and also leaves one; a list over 150 extra
# issues (250 on rest) returns every one across two pages, and
# BEARING_TRACKER_MAX_PAGES=1 stops it with a note; a token holding a double
# quote and a backslash reaches the server byte for byte.
set -u
. "$(dirname "$0")/../lib/assert.sh"
TR="$KIT/plugins/bearing/bin/brg-tracker"
FAKE="$KIT/tests/contract/fake_tracker.py"
work="$(tmpdir)"
fakecfg="$(tmpdir)"
fakehome="$(tmpdir)"
LOG="$work/requests.log"; : > "$LOG"
SLOWLOG="$work/slow.log"; : > "$SLOWLOG"

python3 "$FAKE" --log "$LOG" --port-file "$work/port" >"$work/server.out" 2>&1 & FAST_PID=$!
python3 "$FAKE" --log "$SLOWLOG" --port-file "$work/slowport" --delay 35 >"$work/slow.out" 2>&1 & SLOW_PID=$!
cleanup() { kill "$FAST_PID" "$SLOW_PID" 2>/dev/null; wait "$FAST_PID" "$SLOW_PID" 2>/dev/null; _t_cleanup; }
trap cleanup EXIT
wait_port() { local i=0; while [ ! -s "$1" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done; [ -s "$1" ]; }
wait_port "$work/port" || { echo "fake tracker did not start" >&2; exit 1; }
wait_port "$work/slowport" || { echo "slow fake tracker did not start" >&2; exit 1; }
PORT="$(tr -d '[:space:]' < "$work/port")"; SLOWPORT="$(tr -d '[:space:]' < "$work/slowport")"
URL="http://127.0.0.1:$PORT"; SLOWURL="http://127.0.0.1:$SLOWPORT"
EMAIL="probe@example.com"
PROJECT=""; TOKEN=""; MAXP=20

# tracker <BEARING_TRACKER> <args...>: brg-tracker with the adapter's config in
# the environment only, every real config location pointed at empty dirs.
tracker() {
  local t="$1"; shift
  env -u BEARING_TRACKER_PASSWORD -u BEARING_TASK_ID_PREFIX -u BEARING_TRACKER_DONE_STATUS -u BEARING_JIRA_TYPES -u BEARING_TRACKER_MFA_CODE \
    BEARING_ENV=/nonexistent XDG_CONFIG_HOME="$fakecfg" HOME="$fakehome" \
    BEARING_TRACKER="$t" BEARING_TRACKER_URL="$URL" BEARING_TRACKER_PROJECT="$PROJECT" BEARING_TRACKER_EMAIL="$EMAIL" BEARING_TRACKER_TOKEN="$TOKEN" BEARING_TRACKER_MAX_PAGES="$MAXP" \
    bash "$TR" "$@"
}
commands=0
# ok <tracker> <args...>: exit 0, output holds no token, counted.
ok() { assert_exit 0 tracker "$@"; assert_not_contains "$T_OUT" "$TOKEN" "token leaked by: $*"; commands=$((commands+1)); }
# logged <request line>: at least one log entry for that method and path.
logged() { _t_count; if grep -q "^$1" "$LOG"; then :; else _t_fail "no request [$1] in the server log"; fi; }
# header <exact header line>: the credential arrived in that form.
header() { _t_count; if grep -qF "H: $1" "$LOG"; then :; else _t_fail "header [$1] never arrived"; fi; }

t_begin "the stub answers"
assert_exit 0 curl -sS --max-time 5 "$URL/healthz"
assert_contains "$T_OUT" '"ok": true'
t_end

# ---- Jira
t_begin "jira: ten commands, basic auth, issue links"
PROJECT="PROJ"; TOKEN="sekrit-jira-0f9a"
ok jira config
assert_contains "$T_OUT" "tracker: jira (from environment)"
assert_contains "$T_OUT" "adapter: bin/brg-jira"
assert_contains "$T_OUT" "auth: token set"
assert_contains "$T_OUT" "email: $EMAIL"
ok jira me
assert_eq '{"accountId":"5b10ac8d","name":"Probe User","email":"probe@example.com"}' "$T_OUT" "jira me"
ok jira get PROJ-1
assert_eq '{"key":"PROJ-1","id":"10001","type":"Story","title":"Probe issue","status":"To Do","assignee":null,"priority":"High","parent":null}' "$T_OUT" "jira get"
ok jira list
assert_eq 2 "$(printf '%s\n' "$T_OUT" | grep -c '"key":"PROJ-')" "jira list rows"
ok jira create --type story --title x
assert_contains "$T_OUT" '"key":"PROJ-3"'
ok jira update PROJ-1 --status Done
assert_contains "$T_OUT" '"key":"PROJ-1"'
ok jira comment PROJ-1 "a comment"
assert_eq "brg-jira: comment 5001 posted on PROJ-1" "$T_OUT"
ok jira link PROJ-1 relates PROJ-2
assert_eq "$(printf 'brg-jira: PROJ-1 relates PROJ-2\nlink: issue-link')" "$T_OUT" "jira link"
ok jira close PROJ-1
assert_contains "$T_OUT" '"key":"PROJ-1"'
ok jira trace PROJ-1 --branch feature/PROJ-1-probe --mr http://mr/1
assert_eq "brg-jira: trace comment posted on PROJ-1, 0 test issue link(s) added" "$T_OUT"
b64="$(printf '%s:%s' "$EMAIL" "$TOKEN" | base64 | tr -d '\n')"
header "Authorization: Basic $b64"
logged "GET /rest/api/3/myself"
logged "GET /rest/api/3/issue/PROJ-1?fields="
logged "GET /rest/api/3/search/jql?jql="
logged "POST /rest/api/3/issue$"
logged "GET /rest/api/3/issue/PROJ-1/transitions"
logged "POST /rest/api/3/issue/PROJ-1/transitions"
logged "POST /rest/api/3/issue/PROJ-1/comment"
logged "POST /rest/api/3/issueLink"
assert_exit 1 tracker jira get lowercase-1
assert_contains "$T_OUT" "is not a Jira key like PROJ-123"
assert_not_contains "$T_OUT" "$TOKEN"
t_end

# ---- GitLab
t_begin "gitlab: ten commands, PRIVATE-TOKEN, issue links"
PROJECT="group/repo"; TOKEN="sekrit-gitlab-1b2c"
ok gitlab config
assert_contains "$T_OUT" "adapter: bin/brg-gitlab"
assert_contains "$T_OUT" "url: $URL"
ok gitlab me
assert_eq '{"id":1,"username":"probe","name":"Probe User"}' "$T_OUT" "gitlab me"
ok gitlab get GL-1
assert_contains "$T_OUT" '"key":"GL-1","iid":1,"type":"story","title":"Probe issue","status":"todo"'
ok gitlab list
assert_eq 2 "$(printf '%s\n' "$T_OUT" | grep -c '"key":"GL-')" "gitlab list rows"
ok gitlab create --type story --title x
assert_contains "$T_OUT" '"key":"GL-3"'
ok gitlab update GL-1 --status Done
assert_contains "$T_OUT" '"key":"GL-1"'
ok gitlab comment GL-1 "a comment"
assert_eq "brg-gitlab: note 9 posted on GL-1" "$T_OUT"
ok gitlab link GL-1 relates GL-2
assert_eq "$(printf 'brg-gitlab: GL-1 relates GL-2\nlink: issue-link')" "$T_OUT" "gitlab link"
ok gitlab close GL-1
assert_contains "$T_OUT" '"key":"GL-1"'
ok gitlab trace GL-1 --branch feature/GL-1-probe --mr http://mr/1
assert_eq "brg-gitlab: trace note posted on GL-1, 0 test issue link(s) added" "$T_OUT"
header "PRIVATE-TOKEN: $TOKEN"
logged "GET /api/v4/user"
logged "GET /api/v4/projects/group%2Frepo/issues/1$"
logged "GET /api/v4/projects/group%2Frepo/issues?per_page=100&state=opened"
logged "POST /api/v4/projects/group%2Frepo/issues$"
logged "PUT /api/v4/projects/group%2Frepo/issues/1$"
logged "POST /api/v4/projects/group%2Frepo/issues/1/notes"
logged "POST /api/v4/projects/group%2Frepo/issues/1/links"
t_end

# ---- GitHub (a non-github.com host, so the API root is <url>/api/v3)
t_begin "github: ten commands, bearer token, cross-reference comments"
PROJECT="acme/probe"; TOKEN="sekrit-github-3d4e"
ok github config
assert_contains "$T_OUT" "adapter: bin/brg-github"
ok github me
assert_eq '{"login":"probe","name":"Probe User"}' "$T_OUT" "github me"
ok github get GH-1
assert_contains "$T_OUT" '"key":"GH-1","number":1,"type":"story","title":"Probe issue","status":"todo"'
ok github list
assert_eq 2 "$(printf '%s\n' "$T_OUT" | grep -c '"key":"GH-')" "github list rows"
ok github create --type story --title x
assert_contains "$T_OUT" '"key":"GH-3"'
ok github update GH-1 --status Done
assert_contains "$T_OUT" '"key":"GH-1"'
ok github comment GH-1 "a comment"
assert_eq "brg-github: comment 11 posted on GH-1" "$T_OUT"
ok github link GH-1 relates GH-2
assert_eq "$(printf 'brg-github: GH-1 relates GH-2 (cross-reference comments; GitHub has no issue links)\nlink: comment')" "$T_OUT" "github link"
ok github close GH-1
assert_contains "$T_OUT" '"key":"GH-1"'
ok github trace GH-1 --branch feature/GH-1-probe --mr http://mr/1
assert_eq "brg-github: trace comment posted on GH-1" "$T_OUT"
header "Authorization: Bearer $TOKEN"
header "X-GitHub-Api-Version: 2022-11-28"
logged "GET /api/v3/user"
logged "GET /api/v3/repos/acme/probe/issues/1$"
logged "GET /api/v3/repos/acme/probe/issues?state=open"
logged "GET /api/v3/repos/acme/probe/labels/type%3Astory"
logged "POST /api/v3/repos/acme/probe/issues$"
logged "PATCH /api/v3/repos/acme/probe/issues/1$"
logged "POST /api/v3/repos/acme/probe/issues/1/comments"
logged "POST /api/v3/repos/acme/probe/issues/2/comments"
t_end

# ---- REST tracker protocol (the key is whatever the server returns: PP-17)
t_begin "rest: ten commands, bearer token, key resolution"
PROJECT="PP"; TOKEN="sekrit-rest-5f6a"
ok rest config
assert_contains "$T_OUT" "tracker: rest (from environment)"
assert_contains "$T_OUT" "adapter: bin/brg-rest"
ok rest me
assert_contains "$T_OUT" '"email": "probe@example.com"'
ok rest get PP-17
assert_contains "$T_OUT" '"key": "PP-17"'
ok rest list
assert_eq 2 "$(printf '%s\n' "$T_OUT" | grep -c '"key":"PP-')" "rest list rows"
ok rest create --type story --title x
assert_contains "$T_OUT" '"key": "PP-19"'
ok rest update PP-17 --status Done
assert_contains "$T_OUT" '"key": "PP-17"'
ok rest comment PP-17 "a comment"
assert_contains "$T_OUT" '"issue_id": 17'
ok rest link PP-17 relates PP-18
assert_eq "$(printf 'brg-rest: PP-17 relates PP-18\nlink: issue-link')" "$T_OUT" "rest link"
ok rest close PP-17
assert_contains "$T_OUT" '"key": "PP-17"'
ok rest trace PP-17 --branch feature/PP-17-probe --mr http://mr/1
assert_eq "brg-rest: trace comment posted on PP-17, 0 test issue link(s) added" "$T_OUT"
header "Authorization: Bearer $TOKEN"
logged "GET /api/auth/me"
logged "GET /api/search?q=PP-17"
logged "GET /api/issues/17$"
logged "GET /api/projects/PP/issues?limit=200"
logged "POST /api/projects/PP/issues$"
logged "GET /api/projects/PP/statuses"
logged "PUT /api/issues/17$"
logged "POST /api/issues/17/comments"
logged "POST /api/issues/17/links"
_t_count; grep -q "^POST /api/auth/login" "$LOG" && _t_fail "a token was set, yet the client logged in with a password"
_t_count; [ -e "$fakecfg/bearing/rest.token" ] && _t_fail "a token file was written under the fake config dir"
t_end

# ---- every token stayed out of the output and inside the log
t_begin "secrets"
_t_count; grep -q "sekrit-" "$LOG" || _t_fail "no token reached the server at all"
requests="$(grep -cE '^(GET|POST|PUT|PATCH|DELETE) /' "$LOG")"
assert_eq 1 "$([ "$requests" -ge 40 ] && echo 1)" "at least forty requests served ($requests)"
t_end

# ---- the stateful fake's controls (never logged, never seen by an adapter)
ctl() { curl -sS --max-time 5 -X "$1" "$URL$2"; }
state() { ctl GET "/_state?tracker=$1" | jq -r "$2"; }
titled() { state "$1" "[.titles[] | select(. == \"$2\")] | length"; }
# use <brg-tracker name>: the project and token that adapter's cases need.
use() {
  case "$1" in
    jira) PROJECT="PROJ"; TOKEN="sekrit-jira-0f9a"; STORE=jira; KEY1=PROJ-1;;
    gitlab) PROJECT="group/repo"; TOKEN="sekrit-gitlab-1b2c"; STORE=gitlab; KEY1=GL-1;;
    github) PROJECT="acme/probe"; TOKEN="sekrit-github-3d4e"; STORE=github; KEY1=GH-1;;
    rest) PROJECT="PP"; TOKEN="sekrit-rest-5f6a"; STORE=rest; KEY1=PP-17;;
  esac
}
ADAPTERS="jira gitlab github rest"

# ---- a POST that failed after it applied is not sent twice
retried=0
for t in $ADAPTERS; do
  t_begin "$t: a create and a comment answered 502 after applying leave one item each"
  use "$t"
  before="$(state "$STORE" .issues)"
  _t_count; [ "$(ctl POST /_fault?mode=after)" = '{"fault": "after"}' ] || _t_fail "fault not armed"
  ok "$t" create --type story --title "after-$t"
  assert_contains "$T_OUT" "answered 502 but had been applied; not sent again"
  assert_eq 1 "$(titled "$STORE" "after-$t")" "$t: issues titled after-$t"
  assert_eq $((before + 1)) "$(state "$STORE" .issues)" "$t: issue count after one create"
  comments="$(state "$STORE" .comments)"
  ctl POST /_fault?mode=after >/dev/null
  ok "$t" comment "$KEY1" "after-fault comment"
  assert_contains "$T_OUT" "answered 502 but had been applied; not sent again"
  assert_eq $((comments + 1)) "$(state "$STORE" .comments)" "$t: comment count after one comment"
  # the control: refused before it applied, so the search finds nothing and it is sent again
  ctl POST /_fault?mode=before >/dev/null
  posts="$(grep -c '^POST ' "$LOG")"
  ok "$t" create --type story --title "before-$t"
  assert_not_contains "$T_OUT" "had been applied"
  assert_eq 1 "$(titled "$STORE" "before-$t")" "$t: issues titled before-$t"
  assert_eq $((posts + 2)) "$(grep -c '^POST ' "$LOG")" "$t: the refused create was sent twice"
  retried=$((retried + 1))
  t_end
done

# ---- every page, and the page cap says so
paged=0
for t in $ADAPTERS; do
  t_begin "$t: list returns every issue across two pages; the cap says when it stops"
  use "$t"
  n=150; [ "$t" != rest ] || n=250
  ctl POST "/_seed?tracker=$STORE&n=$n" >/dev/null
  want="$(state "$STORE" .issues)"
  assert_eq 1 "$([ "$want" -gt "$n" ] && echo 1)" "$t: the fake holds $want issues"
  ok "$t" list
  got="$(printf '%s\n' "$T_OUT" | grep -c '"key": *"')"
  assert_eq "$want" "$got" "$t: listed issues"
  assert_contains "$T_OUT" "$want issue(s) listed from 2 page(s)"
  MAXP=1; ok "$t" list; MAXP=20
  assert_contains "$T_OUT" "stopped after 1 page(s) at BEARING_TRACKER_MAX_PAGES=1; more issue(s) exist"
  ok "$t" list --limit 3
  assert_eq 3 "$(printf '%s\n' "$T_OUT" | grep -c '"key": *"')" "$t: --limit 3"
  assert_contains "$T_OUT" "stopped at --limit 3; more issue(s) exist"
  paged=$((paged + 1))
  t_end
done

# ---- a token with a double quote and a backslash arrives intact
quoted=0
for t in $ADAPTERS; do
  t_begin "$t: a token holding a double quote and a backslash reaches the server byte for byte"
  use "$t"
  TOKEN='sekrit-q"uo\te'
  ok "$t" me
  case "$t" in
    jira) header "Authorization: Basic $(printf '%s:%s' "$EMAIL" "$TOKEN" | base64 | tr -d '\n')";;
    gitlab) header "PRIVATE-TOKEN: $TOKEN";;
    *) header "Authorization: Bearer $TOKEN";;
  esac
  quoted=$((quoted + 1))
  t_end
done

# ---- --max-time: a server that never answers in time fails on one line
t_begin "a 35 s server: one-line failure within 45 s (--max-time 30)"
PROJECT="group/repo"; TOKEN="sekrit-gitlab-slow"
URL="$SLOWURL"
start="$(date +%s)"
assert_exit 1 tracker gitlab me
elapsed=$(( $(date +%s) - start ))
URL="http://127.0.0.1:$PORT"
assert_contains "$T_OUT" "brg-gitlab: cannot reach $SLOWURL: curl: (28)"
assert_eq 1 "$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')" "exactly one line of output"
assert_not_contains "$T_OUT" "$TOKEN"
assert_eq 1 "$([ "$elapsed" -le 45 ] && echo 1)" "failed within 45 s (took $elapsed s)"
assert_eq 1 "$([ "$elapsed" -ge 20 ] && echo 1)" "waited for the budget rather than failing at once (took $elapsed s)"
_t_count; grep -q "^GET /api/v4/user" "$SLOWLOG" || _t_fail "the slow server never saw the request"
t_end

# ---- BEARING_TRACKER=none (tracker_none folded in): reads 0, writes 3
t_begin "none: reads exit 0 with the note, writes exit 3"
PROJECT=""; TOKEN=""
none=0
for c in "me" "get X-1" "list" "resolve X-1"; do
  # shellcheck disable=SC2086
  assert_exit 0 tracker none $c; none=$((none+1))
  assert_eq "tracker: none (set BEARING_TRACKER in ~/.config/bearing/bearing.env)" "$T_OUT" "none read: $c"
done
for c in "create --type story --title x" "update X-1 --status Done" "comment X-1 hi" "link X-1 relates X-2" "close X-1" "trace X-1 --branch b"; do
  # shellcheck disable=SC2086
  assert_exit 3 tracker none $c; none=$((none+1))
  assert_eq "tracker: none (set BEARING_TRACKER in ~/.config/bearing/bearing.env)" "$T_OUT" "none write: $c"
done
assert_exit 0 tracker none config; none=$((none+1))
assert_contains "$T_OUT" "tracker: none (from environment)"
assert_contains "$T_OUT" "id prefix:  (ids look like any id matching"
assert_exit 1 tracker bogus me
assert_contains "$T_OUT" "brg-tracker: unknown BEARING_TRACKER 'bogus' (none | rest | jira | gitlab | github)"
assert_exit 2 tracker none
assert_contains "$T_OUT" "brg-tracker config"
t_end

t_begin "every adapter went through every new case"
assert_eq 4 "$retried" "adapters proven idempotent on retry"
assert_eq 4 "$paged" "adapters proven to paginate"
assert_eq 4 "$quoted" "adapters proven to carry a quoted token"
t_end
echo "tracker_fake_server: 4 adapters, $commands commands, $requests requests logged, $retried idempotent-retry, $paged pagination and $quoted quoted-token adapters, 1 slow call; tracker_none folded in ($none commands)"
t_summary
