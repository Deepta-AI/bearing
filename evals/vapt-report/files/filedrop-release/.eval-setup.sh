#!/usr/bin/env bash
# Builds the fixture history: v1.3.0, four commits to the v1.4.0 tag, then a
# fix on main after the tag. The working tree ends at main. The scanner
# reports are written last and stay untracked, as the scanners leave them:
# claude-security at the v1.4.0 commit (changes since v1.3.0), gstack /cso
# in diff mode over v1.3.0..v1.4.0. Run from the fixture copy.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
D=.eval-data
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"; }

mkdir -p "$D/final"
for f in internal/files/handler.go cmd/api/main.go deploy/k8s/deployment.yaml CHANGELOG.md \
         internal/share/links.go internal/share/links_test.go deploy/k8s/configmap.yaml; do
  mkdir -p "$D/final/$(dirname "$f")"; cp "$f" "$D/final/$f"
done
restore() { cp "$D/final/$1" "$1"; }

# v1.3.0: no share package, no configmap, list and upload only.
rm -rf internal/share deploy/k8s/configmap.yaml
cp "$D/v1.3/handler.go" internal/files/handler.go
cp "$D/v1.3/main.go" cmd/api/main.go
cp "$D/v1.3/deployment.yaml" deploy/k8s/deployment.yaml
cp "$D/v1.3/CHANGELOG.md" CHANGELOG.md
git init -q -b main
at "2026-08-03T11:00:00 +0530"
git add -A -- . ":!$D"
git commit -q -m "release: v1.3.0"
git tag v1.3.0

at "2026-08-20T15:10:00 +0530"
restore internal/files/handler.go
git add internal/files/handler.go
git commit -q -m "feat(files): download and preview endpoints"

at "2026-09-02T12:40:00 +0530"
mkdir -p internal/share
cp "$D/v1.4.0/links.go" internal/share/links.go
cp "$D/v1.4.0/links_test.go" internal/share/links_test.go
restore cmd/api/main.go
git add internal/share cmd/api/main.go
git commit -q -m "feat(share): public share links for single files"

at "2026-09-10T18:05:00 +0530"
restore deploy/k8s/configmap.yaml
restore deploy/k8s/deployment.yaml
git add deploy/k8s
git commit -q -m "chore(deploy): move service settings to the filedrop-config ConfigMap"

at "2026-09-15T10:00:00 +0530"
restore CHANGELOG.md
git add CHANGELOG.md
git commit -q -m "docs: changelog for v1.4.0"
git tag v1.4.0

at "2026-09-18T16:20:00 +0530"
restore internal/share/links.go
restore internal/share/links_test.go
git add internal/share
git commit -q -m "fix(share): expire share links after 7 days (SEC-31)"

REL=$(git rev-parse v1.4.0)
CS=CLAUDE-SECURITY-20260916-1030
mkdir -p "$CS" .gstack/security-reports
printf '*\n' > "$CS/.gitignore"
cp "$D/reports/cs-results.jsonl" "$CS/CLAUDE-SECURITY-RESULTS.jsonl"
printf '{"revision":{"commit":"%s","base":"v1.3.0","scope":"changes"},"verification":{"status":"verified"}}\n' "$REL" \
  > "$CS/CLAUDE-SECURITY-REVISION-${REL:0:12}.json"
cp "$D/reports/cso.json" .gstack/security-reports/2026-09-16-1100.json
rm -rf "$D"
test -z "$(git status --porcelain)"
