#!/usr/bin/env bash
# plan.sh <env>: init the environment against the remote backend, write a
# binary plan and a readable plan under .plans/. Never applies. CI and
# `make plan` both run exactly this script.
set -euo pipefail

env="${1:-}"
[[ "$env" =~ ^(dev|qa|prod)$ ]] || { echo "usage: scripts/plan.sh <dev|qa|prod>" >&2; exit 2; }

root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/envs/$env"
out="$root/.plans"
mkdir -p "$out"

if [ -f "$root/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$root/.env"
  set +a
fi
: "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET is not set (see .env.example)}"
export TF_IN_AUTOMATION=1 TF_INPUT=0

terraform -chdir="$dir" init -input=false -reconfigure -backend-config="bucket=$TF_BACKEND_BUCKET" >/dev/null
echo "plan: $env initialised against gs://$TF_BACKEND_BUCKET/envs/$env"

varfile=()
[ -f "$dir/terraform.tfvars" ] && varfile=(-var-file=terraform.tfvars)

set +e
terraform -chdir="$dir" plan -input=false -lock-timeout=5m -detailed-exitcode \
  ${varfile[@]+"${varfile[@]}"} -out="$out/$env.tfplan"
code=$?
set -e
case "$code" in
  0 | 2) ;;
  *) echo "plan: $env failed (exit $code)" >&2; exit "$code" ;;
esac

terraform -chdir="$dir" show -no-color "$out/$env.tfplan" > "$out/$env.txt"

# GitLab's MR terraform widget reads {create, update, delete}.
if command -v jq >/dev/null; then
  terraform -chdir="$dir" show -json "$out/$env.tfplan" \
    | jq -c '[.resource_changes[]?.change.actions[]?] | {create: (map(select(. == "create")) | length), update: (map(select(. == "update")) | length), delete: (map(select(. == "delete")) | length)}' \
    > "$out/$env.json"
fi

summary="$(grep -E '^Plan: [0-9]+ to add' "$out/$env.txt" || echo 'Plan: 0 to add, 0 to change, 0 to destroy.')"
echo "plan: $env $summary"
destroys="$(printf '%s' "$summary" | sed -E 's/.* ([0-9]+) to destroy.*/\1/')"
if [ "${destroys:-0}" -gt 0 ]; then
  echo "plan: WARNING $env destroys $destroys resource(s). Name each one in the MR description." >&2
fi
if grep -q 'forces replacement' "$out/$env.txt"; then
  echo "plan: WARNING $env replaces a resource. A stateful one is a stop, not a note." >&2
fi
echo "plan: written $out/$env.tfplan and $out/$env.txt (apply is a person's job, from the pipeline)"
