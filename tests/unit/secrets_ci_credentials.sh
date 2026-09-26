#!/usr/bin/env bash
# tests/unit/secrets_ci_credentials.sh: skills/secrets/scripts/ci-credentials.py
# passes CI files that read every credential from the secret store and
# counts a throwaway service-container password without failing; fails, and
# names file, line and key but never the value, on a literal token in a
# GitLab variable, a literal inside a GitHub flow map, a --password flag, a
# URL with a password and a credential-shaped string; fails on zero CI files.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CC="$KIT/skills/secrets/scripts/ci-credentials.py"

clean() {
  local d
  d="$(tmpdir)"
  mkdir -p "$d/.github/workflows"
  cat > "$d/.gitlab-ci.yml" <<'EOF'
variables:
  POSTGRES_PASSWORD: postgres
  DATABASE_URL: "postgres://postgres:postgres@postgres:5432/app_test"
  API_TOKEN: $API_TOKEN
deploy:
  script:
    - crane auth login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
EOF
  cat > "$d/.github/workflows/ci.yml" <<'EOF'
permissions:
  id-token: write
jobs:
  test:
    env: { POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres }
    steps:
      - run: make check
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          CLIENT_SECRET: ""
EOF
  printf '%s' "$d"
}

t_begin "references and throwaway service passwords pass, with counts"
d="$(clean)"
assert_exit 0 python3 "$CC" --root "$d"
assert_contains "$T_OUT" "ci-credentials: 2 CI files, 6 credential keys examined, 3 throwaway service passwords, 0 inline credentials"
t_end

t_begin "a literal token in a GitLab variable fails without printing it"
d="$(clean)"
printf 'more:\n  variables:\n    DEPLOY_TOKEN: q8Zr4LmN2vX7\n' >> "$d/.gitlab-ci.yml"
assert_exit 1 python3 "$CC" --root "$d"
assert_contains "$T_OUT" "finding: .gitlab-ci.yml:10: key DEPLOY_TOKEN has a literal value"
assert_not_contains "$T_OUT" "q8Zr4LmN2vX7"
t_end

t_begin "a literal in a flow map, a --password flag and a URL password fail"
d="$(clean)"
cat >> "$d/.github/workflows/ci.yml" <<'EOF'
      - run: psql --password=Hunter2x "postgres://app:S3cretPw@db.internal/app"
    services:
      mq: { image: rabbitmq, env: { RABBITMQ_DEFAULT_PASS: guest, API_KEY: live9Kq } }
EOF
assert_exit 1 python3 "$CC" --root "$d"
assert_contains "$T_OUT" "ci.yml:11: --password is given a literal"
assert_contains "$T_OUT" "ci.yml:13: key API_KEY has a literal value"
assert_not_contains "$T_OUT" "Hunter2x"
assert_not_contains "$T_OUT" "live9Kq"
printf '    - run: psql "postgres://app:S3cretPw@db.internal/app"\n' >> "$d/.github/workflows/ci.yml"
assert_exit 1 python3 "$CC" --root "$d"
assert_contains "$T_OUT" "ci.yml:14: a URL carries a password"
assert_not_contains "$T_OUT" "S3cretPw"
t_end

t_begin "a credential-shaped string fails"
d="$(clean)"
printf 'x:\n  script:\n    - echo AKIAABCDEFGHIJKLMNOP\n' >> "$d/.gitlab-ci.yml"
assert_exit 1 python3 "$CC" --root "$d"
assert_contains "$T_OUT" ".gitlab-ci.yml:10: a credential-shaped string"
t_end

t_begin "zero CI files fail"
d="$(tmpdir)"
assert_exit 1 python3 "$CC" --root "$d"
assert_contains "$T_OUT" "ci-credentials: 0 CI files"
t_end

t_summary
