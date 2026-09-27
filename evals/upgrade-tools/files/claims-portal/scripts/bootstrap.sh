#!/usr/bin/env bash
# Clone every source in .claude/tooling.lock from the mirror, check out the
# pinned commit, apply the local patches, and relink gstack's skills.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY' > .bootstrap.tsv
import json
for s in json.load(open(".claude/tooling.lock"))["sources"]:
    print("\t".join([s["name"], s["url"], s["ref"], s["path"]]))
PY
n=0
while IFS=$'\t' read -r name url ref path; do
  if [ ! -d "$path/.git" ]; then
    git clone -q "$url" "$path"
  else
    git -C "$path" fetch -q origin --tags
  fi
  git -C "$path" checkout -q --detach "$ref"
  for p in .claude/patches/"$name"-*.patch; do
    [ -e "$p" ] || continue
    if git -C "$path" apply --check -R "$PWD/$p" 2>/dev/null; then
      echo "bootstrap: $p already applied"
    else
      git -C "$path" apply "$PWD/$p"
      echo "bootstrap: applied $p"
    fi
  done
  n=$((n + 1))
done < .bootstrap.tsv
rm -f .bootstrap.tsv
[ -x .claude/skills/gstack/setup ] && (cd .claude/skills/gstack && ./setup)
[ "$n" -gt 0 ] || { echo "bootstrap: 0 sources in .claude/tooling.lock" >&2; exit 1; }
echo "bootstrap: $n sources at their pinned commits; restart Claude Code to load them"
