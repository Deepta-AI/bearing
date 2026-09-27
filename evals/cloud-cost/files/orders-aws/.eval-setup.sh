#!/usr/bin/env bash
# Builds the history: the tree as of 20 July, prod switched to debug logging
# on 4 August, the July cost review on 5 August, the August export and
# request volume on 2 September. Run from the fixture copy; removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"; }
git init -q -b main

cp docs/observability/slos.md slos.final
grep -v '^| 2026-08 |' slos.final > docs/observability/slos.md
cp k8s/prod/orders-api.yaml prod.final
sed -i 's/value: debug .*$/value: info/' k8s/prod/orders-api.yaml
at "2026-07-20T11:00:00 +0530"
git add -A -- . ':!billing' ':!docs/cost' ':!slos.final' ':!prod.final'
git commit -q -m "orders: infra, manifests and docs"

cp prod.final k8s/prod/orders-api.yaml
at "2026-08-04T19:20:00 +0530"
git add k8s/prod/orders-api.yaml
git commit -q -m "orders-api prod: debug logging to chase the refund mismatch (INC-212), revert when fixed"

at "2026-08-05T16:00:00 +0530"
git add docs/cost
git commit -q -m "docs: July cost review"

mv slos.final docs/observability/slos.md
rm prod.final
at "2026-09-02T10:15:00 +0530"
git add -A
git commit -q -m "billing: August CUR extract, August request volume"
