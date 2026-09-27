#!/usr/bin/env bash
# Builds this fixture's history: releases v1.3.0, v1.4.0 and v1.4.2 on main,
# then two unreleased commits after v1.4.2. The files on disk are the final
# tree; earlier versions are written here. Removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# The parser before the IST fix, its test without the IST case, and the
# older eslint pin.
cat > src/parse.js <<'JS'
// Parses a partner lab's report payload into the fields we file.

const REQUIRED = ['labId', 'patientRef', 'collectedAt', 'results'];

export function parseReport(body) {
  for (const key of REQUIRED) {
    if (!(key in body)) throw new Error(`missing ${key}`);
  }
  const collectedAt = new Date(body.collectedAt);
  if (Number.isNaN(collectedAt.getTime())) throw new Error('bad collectedAt');
  return {
    labId: String(body.labId),
    patientRef: String(body.patientRef).trim().toUpperCase(),
    collectedAt,
    results: body.results.map((r) => ({ code: r.code, value: r.value, unit: r.unit ?? null })),
  };
}
JS
python3 - <<'PY'
s = open('test/parse.test.js').read()
start = s.index("test('assumes IST")
end = s.index("test('rejects")
open('test/parse.test.js', 'w').write(s[:start] + s[end:])
PY
sed -i 's/9\.17\.0/9.9.0/g' package.json package-lock.json

git init -q -b main
git remote add origin git@gitlab.example.com:harbor/lab-intake.git
git add -A
at "2026-04-06T11:00:00"; git commit -q -m "release: v1.3.0"
git tag -a v1.3.0 -m v1.3.0
printf '\nProduction runs 3 replicas behind the clinic group ingress.\n' >> docs/design/hld.md
git add -A
at "2026-06-18T16:20:00"; git commit -q -m "feat(deploy): production on the clinic group domain [LAB-188]"
git tag -a v1.4.0 -m v1.4.0
restore docs/design/hld.md
git add -A
at "2026-08-20T18:45:00"; git commit -q -m "fix(store): drop the replica note from the HLD [LAB-207]"
git tag -a v1.4.2 -m v1.4.2

restore package.json package-lock.json
git add -A
at "2026-09-08T10:05:00"; git commit -q -m "chore(deps): eslint 9.17.0"
restore src/parse.js test/parse.test.js
git add -A
at "2026-09-22T15:30:00"; git commit -q -m "fix(parse): assume IST when collectedAt has no zone [LAB-219]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
rm -r "$final"
