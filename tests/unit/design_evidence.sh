#!/usr/bin/env bash
# tests/unit/design_evidence.sh: plugins/bearing/skills/design-critique/scripts/evidence.py
# check passes six real-shaped PNGs per page with a dark theme that applied,
# and fails, with the reason, on a missing width, a PNG at the wrong width,
# a file that is not a PNG, a dark shot identical to light, equal computed
# colours, a missing theme record, and zero pages. shoot fails on a page that
# is not in the folder, and when neither browse nor chrome can be used. No
# browser is needed: the PNGs are written here.
set -u
. "$(dirname "$0")/../lib/assert.sh"
EV="$KIT/plugins/bearing/skills/design-critique/scripts/evidence.py"

# png <path> <width> <salt>: a PNG signature and IHDR of that width; the salt
# changes the bytes so light and dark differ.
png() { python3 -c 'import struct,sys
w=int(sys.argv[2]); open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+struct.pack(">I",13)+b"IHDR"+struct.pack(">II",w,800)+b"\x08\x02\x00\x00\x00"+sys.argv[3].encode())' "$1" "$2" "$3"; }
# page <dir> <name>: six shots and a theme record whose colours differ.
page() {
  for w in 375 768 1440; do png "$1/$2-$w.png" "$w" light; png "$1/$2-$w-dark.png" "$w" dark; done
  printf '{"url":"x","light":"[\\"white|black\\"]","dark":"[\\"black|white\\"]"}\n' > "$1/$2.theme.json"
}

t_begin "six shots per page with a dark theme that applied pass"
d="$(tmpdir)"; page "$d" home; page "$d" settings
assert_exit 0 python3 "$EV" check --out "$d" home.html settings.html
assert_contains "$T_OUT" "design-evidence: 2 pages, 12 of 12 screenshots present (375/768/1440 light and dark), 6 of 6 dark shots differ from light, 0 problems"
t_end

t_begin "a missing width, a wrong width and a non-PNG fail"
d="$(tmpdir)"; page "$d" home
rm "$d/home-768-dark.png"; png "$d/home-1440.png" 1000 light; printf 'not a png' > "$d/home-375.png"
assert_exit 1 python3 "$EV" check --out "$d" home.html
assert_contains "$T_OUT" "missing home-768-dark.png"
assert_contains "$T_OUT" "home-1440.png is 1000 px wide, not a 1440 viewport"
assert_contains "$T_OUT" "home-375.png is not a PNG"
assert_contains "$T_OUT" "3 of 6 screenshots present"
t_end

t_begin "a device pixel ratio of 2 is accepted"
d="$(tmpdir)"; page "$d" home
for w in 375 768 1440; do png "$d/home-$w.png" $((w*2)) light; png "$d/home-$w-dark.png" $((w*2)) dark; done
assert_exit 0 python3 "$EV" check --out "$d" home.html
t_end

t_begin "a dark theme that never applied is a failed check"
d="$(tmpdir)"; page "$d" home
cp "$d/home-375.png" "$d/home-375-dark.png"
printf '{"url":"x","light":"[\\"white|black\\"]","dark":"[\\"white|black\\"]"}\n' > "$d/home.theme.json"
assert_exit 1 python3 "$EV" check --out "$d" home.html
assert_contains "$T_OUT" "dark 375 is byte-identical to light"
assert_contains "$T_OUT" "computed colours are equal in light and dark"
assert_contains "$T_OUT" "2 of 3 dark shots differ"
t_end

t_begin "a missing theme record, zero pages and an absent browse fail"
d="$(tmpdir)"; page "$d" home; rm "$d/home.theme.json"
assert_exit 1 python3 "$EV" check --out "$d" home.html
assert_contains "$T_OUT" "no home.theme.json"
assert_exit 1 python3 "$EV" check --out "$d"
assert_contains "$T_OUT" "0 pages given, nothing checked"
assert_exit 1 python3 "$EV" shoot --base "$d" --out "$d/o" --browse "$d/no-browse" home.html
assert_contains "$T_OUT" "no such page in"
printf '<!doctype html><title>x</title>\n' > "$d/home.html"
assert_exit 1 python3 "$EV" shoot --base "$d" --out "$d/o" --browse "$d/no-browse" --chrome "$d/no-chrome" home.html
assert_contains "$T_OUT" "no chrome or chromium found; no screenshots taken"
t_end

t_begin "the chrome fallback waits for hydration and entrances before each screenshot"
d="$(tmpdir)"; printf '<!doctype html><title>x</title>\n' > "$d/home.html"
cat > "$d/fake-chrome" <<'EOF2'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$(dirname "$0")/chrome-args"
for a in "$@"; do case "$a" in --screenshot=*) : > "${a#--screenshot=}";; esac; done
EOF2
chmod 755 "$d/fake-chrome"
assert_exit 0 python3 "$EV" shoot --base "$d" --out "$d/o" --browse "$d/no-browse" --chrome "$d/fake-chrome" home.html
assert_eq "6" "$(grep -c -- '--virtual-time-budget=' "$d/chrome-args" | tr -d ' ')" "every shot waits"
t_end

t_begin "browse keeps its state outside the repository; a left-over tool folder is removed and named"
d="$(tmpdir)"; git -C "$d" init -q; printf '<!doctype html><title>x</title>\n' > "$d/home.html"
cat > "$d/fake-browse" <<'EOF2'
#!/usr/bin/env bash
# a stand-in for gstack browse: state goes where BROWSE_STATE_FILE says,
# else to <git root>/.gstack; screenshots are real-shaped PNGs.
dir="$(dirname "${BROWSE_STATE_FILE:-$(git rev-parse --show-toplevel)/.gstack/browse.json}")"
mkdir -p "$dir"; echo "$*" >> "$dir/browse-daemon.log"
case "$1" in
  viewport) echo "${2%x*}" > "$dir/w" ;;
  screenshot) python3 -c 'import struct,sys
w=int(open(sys.argv[2]).read()); open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+struct.pack(">I",13)+b"IHDR"+struct.pack(">II",w,800)+sys.argv[1].encode())' "$3" "$dir/w" ;;
  js) case "$2" in
        *dataset.theme*) touch "$dir/dark" ;;
        *) if test -e "$dir/dark"; then echo '["dark"]'; else echo '["light"]'; fi ;;
      esac ;;
esac
EOF2
chmod +x "$d/fake-browse"
(cd "$d" || exit 1; python3 "$EV" shoot --base "$d" --out "$d/shots" --browse "$d/fake-browse" home.html) > "$d/shoot.out" 2>&1
assert_exit 0 test -s "$d/shots/home-1440-dark.png"
T_OUT="$(cat "$d/shoot.out")"
assert_contains "$T_OUT" "engine browse, dark via data-theme"
assert_not_contains "$T_OUT" "removed"
assert_exit 1 test -e "$d/.gstack"
assert_exit 0 python3 "$EV" check --out "$d/shots" home.html
assert_contains "$T_OUT" "dark shot via data-theme"
t_end

t_summary

t_begin "the query keys that change the picture name the files; chrome and theme do not"
assert_eq "S-01~state-error~variant-2-plot" "$(python3 -c "import sys;sys.path.insert(0,'$(dirname "$EV")');import evidence;print(evidence.stem('__design/S-01?state=error&chrome=0&variant=2-plot&theme=dark'))")" "stem"
assert_eq "list" "$(python3 -c "import sys;sys.path.insert(0,'$(dirname "$EV")');import evidence;print(evidence.stem('list.html#chrome=0'))")" "stem without a query"
t_end
