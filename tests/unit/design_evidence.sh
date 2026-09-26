#!/usr/bin/env bash
# tests/unit/design_evidence.sh: skills/design-critique/scripts/evidence.py
# check passes six real-shaped PNGs per page with a dark theme that applied,
# and fails, with the reason, on a missing width, a PNG at the wrong width,
# a file that is not a PNG, a dark shot identical to light, equal computed
# colours, a missing theme record, and zero pages. shoot fails when browse is
# absent. No browser is needed: the PNGs are written here.
set -u
. "$(dirname "$0")/../lib/assert.sh"
EV="$KIT/skills/design-critique/scripts/evidence.py"

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
assert_contains "$T_OUT" "browse not executable"
t_end

t_summary
