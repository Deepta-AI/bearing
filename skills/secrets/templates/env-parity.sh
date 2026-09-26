#!/usr/bin/env bash
# env-parity: every environment variable read in code is named in
# .env.example, and every name in .env.example is read somewhere.
# Prints counts, exits 1 on zero variables read or any missing name.
# Values are never read; only names.
set -euo pipefail

example="${1:-.env.example}"
root="${2:-.}"

names_in_code() {
  grep -rhoE \
    -e 'os\.Getenv\("[A-Z][A-Z0-9_]*"' \
    -e 'os\.LookupEnv\("[A-Z][A-Z0-9_]*"' \
    -e 'envconfig:"[A-Z][A-Z0-9_]*"' \
    -e 'os\.environ\[["'"'"'][A-Z][A-Z0-9_]*' \
    -e 'os\.environ\.get\(["'"'"'][A-Z][A-Z0-9_]*' \
    -e 'os\.getenv\(["'"'"'][A-Z][A-Z0-9_]*' \
    -e 'process\.env\.[A-Z][A-Z0-9_]*' \
    -e 'import\.meta\.env\.[A-Z][A-Z0-9_]*' \
    -e 'System\.getenv\("[A-Z][A-Z0-9_]*"' \
    --include='*.go' --include='*.py' --include='*.ts' --include='*.tsx' \
    --include='*.js' --include='*.mjs' --include='*.kt' --include='*.java' \
    --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=dist \
    --exclude-dir=.venv --exclude-dir=build --exclude-dir=.git \
    "$root" 2>/dev/null | sed 's/["'"'"']$//' | grep -oE '[A-Z][A-Z0-9_]*$' | sort -u
}

names_in_example() {
  [ -f "$example" ] || return 0
  grep -oE '^[A-Z][A-Z0-9_]*=' "$example" | tr -d '=' | sort -u
}

code="$(names_in_code || true)"
ex="$(names_in_example || true)"
n="$(printf '%s\n' "$code" | sed '/^$/d' | wc -l | tr -d ' ')"
m="$(printf '%s\n' "$ex" | sed '/^$/d' | wc -l | tr -d ' ')"
missing="$(comm -23 <(printf '%s\n' "$code" | sed '/^$/d') <(printf '%s\n' "$ex" | sed '/^$/d'))"
unused="$(comm -13 <(printf '%s\n' "$code" | sed '/^$/d') <(printf '%s\n' "$ex" | sed '/^$/d'))"
k="$(printf '%s\n' "$missing" | sed '/^$/d' | wc -l | tr -d ' ')"
u="$(printf '%s\n' "$unused" | sed '/^$/d' | wc -l | tr -d ' ')"

echo "env vars: $n read in code, $m in $example, $k missing, $u unused"
[ "$n" -gt 0 ] || { echo "env-parity: 0 variables read in code under $root; nothing checked" >&2; exit 1; }
if [ "$k" -gt 0 ]; then
  echo "missing from $example:" >&2
  printf '  %s\n' $missing >&2
  exit 1
fi
[ "$u" -eq 0 ] || { echo "unused in code (warning):"; printf '  %s\n' $unused; }
exit 0
