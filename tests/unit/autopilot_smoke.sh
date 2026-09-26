#!/usr/bin/env bash
# tests/unit/autopilot_smoke.sh: the headless run hands its smoke to the
# launcher. On 26 Sep 2026 a run under the template sandbox could not start
# Docker or read .env, so the dod gate refused and a person ran the smoke by
# hand. Now the model calls `brg-autopilot smoke-request` and ends its turn;
# `launch` runs the smoke outside the sandbox (make smoke, else up, the
# model's plan, down), writes .scratch/smoke-<ID>.md and resumes the session
# with the verdict, at most three rounds.
set -u
. "$(dirname "$0")/../lib/assert.sh"
AP="$KIT/bin/brg-autopilot"; export AP
commit() { git -C "$d" add -A >/dev/null 2>&1; git -C "$d" -c user.email=t@e -c user.name=t commit -qm "$1" >/dev/null 2>&1; }

# The fake claude: prints a stream-json init line, records its argv and the
# headless flag, and (FAKE_MODE once|always|never) asks for a smoke.
fake="$(tmpdir)/claude"
cat > "$fake" <<'SH'
#!/usr/bin/env bash
n=$(cat .fake-calls 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > .fake-calls
printf '%s\n' "$@" > ".fake-argv-$n"
printf '%s\n' "${BRG_AUTOPILOT_HEADLESS:-unset}" > ".fake-env-$n"
printf '{"type":"system","subtype":"init","session_id":"sess-abc","tools":[]}\n'
case "${FAKE_MODE:-once}" in
  always) python3 "$AP" smoke-request --id T-9 --dir "$PWD" ;;
  once) [ "$n" -eq 1 ] && python3 "$AP" smoke-request --id T-9 --dir "$PWD" ;;
esac
printf '{"type":"result","subtype":"success"}\n'
SH
chmod +x "$fake"; export BRG_CLAUDE="$fake"

# repo <makefile-body>: a git repository with an open run and that Makefile.
repo() {
  d="$(tmpdir)/run"
  git init -q -b main "$d"
  printf '%b' "$1" > "$d/Makefile"
  printf '.bearing/state/\n.scratch/\n.fake-*\n' > "$d/.gitignore"; commit init
  python3 "$AP" start "a tiny site" --dir "$d" >/dev/null
}
launch() { ( cd "$d" && python3 "$AP" launch "a tiny site" --dir "$d" ); }
SMOKE_OK='smoke:\n\t@n=$$(cat smoke.count 2>/dev/null || echo 0); echo $$((n+1)) > smoke.count; mkdir -p .scratch; printf "# smoke\\n| GET | / | 200 |\\nsmoke: 3 requests checked, 0 failed\\n" > .scratch/smoke-T-9.md\n'
SMOKE_BAD='smoke:\n\t@n=$$(cat smoke.count 2>/dev/null || echo 0); echo $$((n+1)) > smoke.count; mkdir -p .scratch; printf "# smoke\\nsmoke: 3 requests checked, 1 failed\\n" > .scratch/smoke-T-9.md; exit 1\n'
SMOKE_ZERO='smoke:\n\t@mkdir -p .scratch; printf "smoke: 0 requests checked, 0 failed\\n" > .scratch/smoke-T-9.md\n'

t_begin "a smoke request runs make smoke, then resumes the session naming the file and its verdict"
repo "$SMOKE_OK"
export FAKE_MODE=once
assert_exit 0 launch
assert_contains "$T_OUT" "smoke round 1 of 3"
assert_contains "$T_OUT" "smoke: 3 requests checked, 0 failed"
assert_eq "2" "$(cat "$d/.fake-calls")" "claude calls"
assert_eq "1" "$(cat "$d/smoke.count")" "make smoke runs"
assert_eq "1" "$(cat "$d/.fake-env-1")" "BRG_AUTOPILOT_HEADLESS in the child"
argv2="$(cat "$d/.fake-argv-2")"
assert_contains "$argv2" "--resume"
assert_contains "$argv2" "sess-abc"
assert_contains "$argv2" ".scratch/smoke-T-9.md"
assert_contains "$argv2" "passed"
st="$(cat "$d/.bearing/state/autopilot.json")"
assert_not_contains "$st" '"pending": true' "state after the round"
t_end

t_begin "a failing smoke resumes the session; three failed rounds stop the run non-zero"
repo "$SMOKE_BAD"
export FAKE_MODE=always
assert_exit 1 launch
assert_eq "3" "$(cat "$d/smoke.count")" "make smoke runs"
assert_eq "3" "$(cat "$d/.fake-calls")" "claude calls (the run, then two resumes)"
assert_contains "$(cat "$d/.fake-argv-2")" "1 failed"
assert_contains "$(cat "$d/.fake-argv-2")" "test first"
assert_contains "$T_OUT" "smoke failed 3 rounds of 3; stopping"
t_end

t_begin "no smoke request means no smoke"
repo "$SMOKE_OK"
export FAKE_MODE=never
assert_exit 0 launch
assert_eq "1" "$(cat "$d/.fake-calls")" "claude calls"
assert_eq "no" "$([ -e "$d/smoke.count" ] && echo yes || echo no)" "make smoke ran"
assert_not_contains "$T_OUT" "smoke round"
t_end

t_begin "a smoke that checked 0 requests fails"
repo "$SMOKE_ZERO"
export FAKE_MODE=once
assert_exit 0 launch
assert_contains "$T_OUT" "0 requests"
assert_contains "$(cat "$d/.fake-argv-2")" "failed"
assert_not_contains "$(cat "$d/.fake-argv-2")" "passed"
t_end

t_begin "smoke-request refuses when there is neither a make smoke target nor a plan"
repo 'check:\n\t@true\n'
assert_exit 1 python3 "$AP" smoke-request --id T-9 --dir "$d"
assert_contains "$T_OUT" "smoke-plan-T-9.txt"
mkdir -p "$d/.scratch"; printf 'base http://127.0.0.1:1\n' > "$d/.scratch/smoke-plan-T-9.txt"
assert_exit 1 python3 "$AP" smoke-request --id T-9 --dir "$d"
assert_contains "$T_OUT" "0 checks"
t_end

# The minimal launcher smoke: make up starts a tiny http.server on a free
# port, the model's plan lists the checks, make down always runs.
port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
listening() { python3 -c 'import socket,sys; s=socket.socket(); s.settimeout(1); sys.exit(0 if s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)' "$1"; }
serverrepo() {
  P="$(port)"
  repo "up:\n\t@cp .env env.seen\n\t@python3 -m http.server $P --bind 127.0.0.1 >/dev/null 2>&1 & echo \$\$! > server.pid\ndown:\n\t@kill \`cat server.pid\`; rm -f server.pid; touch down.ran\n"
  printf 'hi\n' > "$d/hello.txt"; printf 'SECRET=local\n' > "$d/.env.example"
  mkdir -p "$d/.scratch"
}

t_begin "without make smoke the launcher runs up, the plan's checks and down, and writes the evidence"
serverrepo
printf '# the checks\nbase http://127.0.0.1:%s\nGET /hello.txt 200\nGET /missing 404\n' "$P" > "$d/.scratch/smoke-plan-T-9.txt"
export FAKE_MODE=once
assert_exit 0 launch
ev="$(cat "$d/.scratch/smoke-T-9.md")"
assert_contains "$ev" "| GET | /hello.txt | 200 | 200 |"
assert_contains "$ev" "| GET | /missing | 404 | 404 |"
assert_contains "$ev" "smoke: 2 requests checked, 0 failed"
assert_eq "SECRET=local" "$(cat "$d/env.seen")" ".env made from .env.example"
assert_eq "no" "$([ -e "$d/.env" ] && echo yes || echo no)" ".env left behind"
assert_file "$d/down.ran"
assert_exit 1 listening "$P"
t_end

t_begin "down runs after a failing check"
serverrepo
printf 'base http://127.0.0.1:%s\nGET /hello.txt 200\nGET /missing 200\n' "$P" > "$d/.scratch/smoke-plan-T-9.txt"
export FAKE_MODE=once
assert_exit 0 launch
assert_contains "$(cat "$d/.scratch/smoke-T-9.md")" "smoke: 2 requests checked, 1 failed"
assert_file "$d/down.ran"
assert_exit 1 listening "$P"
assert_contains "$(cat "$d/.fake-argv-2")" "1 failed"
t_end

t_begin "down runs when up fails, and no request checked is a failure"
P="$(port)"
repo "up:\n\t@exit 3\ndown:\n\t@touch down.ran\n"
mkdir -p "$d/.scratch"; printf 'base http://127.0.0.1:%s\nGET / 200\n' "$P" > "$d/.scratch/smoke-plan-T-9.txt"
export FAKE_MODE=once
assert_exit 0 launch
assert_file "$d/down.ran"
assert_contains "$(cat "$d/.scratch/smoke-T-9.md")" "smoke: 0 requests checked, 0 failed"
assert_contains "$(cat "$d/.fake-argv-2")" "failed"
t_end

t_begin "--print prints the command and runs nothing"
repo "$SMOKE_OK"
assert_exit 0 python3 "$AP" launch "a tiny site" --dir "$d" --print
assert_contains "$T_OUT" "-p"
assert_eq "no" "$([ -e "$d/.fake-calls" ] && echo yes || echo no)" "claude ran"
t_end

t_summary
