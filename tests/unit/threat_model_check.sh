#!/usr/bin/env bash
# tests/unit/threat_model_check.sh: plugins/bearing/skills/threat-model/scripts/threats_check.py
# passes a model whose threats cite an existing file:line, a backlog story
# or a new story, and fails on a malformed or duplicate id, a missing file,
# a line past the end, an unknown story, "handled by the framework", an
# empty mitigation, a sensitive scope with zero threats, and empty input.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/threat-model/scripts/threats_check.py"

# fixture <dir> <row>...: a repository with one code file, a backlog, and a model holding the rows.
fixture() {
  local d="$1"; shift
  mkdir -p "$d/docs/security" "$d/docs/product" "$d/internal/webhooks"
  printf 'package webhooks\n\nfunc Verify() {}\n' > "$d/internal/webhooks/verify.go"
  printf '### US-05-002 Audit log\n' > "$d/docs/product/backlog.md"
  { printf '# Threat model: payments webhook\n\n- Sensitive classes: payments, external input\n\n## 4. Threats (STRIDE)\n\n'
    echo '| Id | Entry or boundary | Category | Threat | Likelihood | Impact | Mitigation | Status |'
    echo '| --- | --- | --- | --- | --- | --- | --- | --- |'
    for r in "$@"; do echo "$r"; done
    printf '\n## 5. Residual risks\n'
  } > "$d/docs/security/threat-model-webhook.md"
}
OK1='| T-01 | E2 | Spoofing | forged webhook | M | H | verify HMAC, internal/webhooks/verify.go:3 | mitigated |'
OK2='| T-02 | E1 | Repudiation | writes unaudited | L | M | US-05-002 | planned |'
OK3='| T-03 | E1 | Elevation | cross-tenant read | M | H | new story: per-record tenant check | planned |'
SKIP='| T-04 | E1 | Tampering | considered, none: body is signed | | | | |'
run() { (cd "$1" && python3 "$CHK"); }

t_begin "a model with checkable mitigations passes with its counts"
d="$(tmpdir)/ok"; fixture "$d" "$OK1" "$OK2" "$OK3" "$SKIP"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "threat-model: 1 files, 3 threats (mitigated 1, planned 2, unmitigated 0; retired 0), mitigations: code 1, story 1, new story 1; 2 sensitive classes, 0 problems"
assert_contains "$T_OUT" "Threats by category: S 1, T 0, R 1, I 0, D 0, E 1"
assert_contains "$T_OUT" "Gate: passed"
t_end

t_begin "a retired threat keeps its id, needs a version and a reason, and is not counted live"
d="$(tmpdir)/retired"; fixture "$d" "$OK1" \
  '| T-02 | E1 | Repudiation | writes unaudited | L | M |  | retired in v2: the audit log moved to the ledger service |' \
  '| T-03 | E1 | Elevation | cross-tenant read | M | H |  | retired |'
assert_exit 1 run "$d"
assert_contains "$T_OUT" "1 threats (mitigated 1, planned 0, unmitigated 0; retired 2)"
assert_contains "$T_OUT" "T-03 is retired without 'retired in v<n>: <reason>'"
assert_not_contains "$T_OUT" "T-02 is retired without"
assert_not_contains "$T_OUT" "T-02 has no mitigation"
assert_contains "$T_OUT" "Threats by category: S 1, T 0, R 0, I 0, D 0, E 0"
t_end

t_begin "malformed and duplicate ids fail"
d="$(tmpdir)/ids"; fixture "$d" "$OK1" "${OK2/T-02/T-01}" "${OK3/T-03/T3}"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "problem: docs/security/threat-model-webhook.md: duplicate threat id T-01"
assert_contains "$T_OUT" "threat id 'T3' is not of the form T-nn"
t_end

t_begin "a missing file, a line past the end and an unknown story fail"
d="$(tmpdir)/cites"; fixture "$d" "${OK1/verify.go:3/verify.go:99}" "${OK2/US-05-002/US-05-009}" \
  '| T-03 | E1 | Tampering | body edited | M | H | internal/webhooks/sign.go:4 | mitigated |'
assert_exit 1 run "$d"
assert_contains "$T_OUT" "T-01 cites internal/webhooks/verify.go:99, past the end of the file"
assert_contains "$T_OUT" "T-02 cites US-05-009, which is not a story"
assert_contains "$T_OUT" "T-03 cites internal/webhooks/sign.go:4, which does not exist"
t_end

t_begin "handled by the framework, an empty and a vague mitigation fail"
d="$(tmpdir)/framework"; fixture "$d" \
  '| T-01 | E1 | Spoofing | forged session | M | H | handled by the framework | mitigated |' \
  '| T-02 | E1 | Tampering | edited body | M | H |  | unmitigated |' \
  '| T-03 | E1 | Denial of service | flood | M | M | rate limiting | planned |'
assert_exit 1 run "$d"
assert_contains "$T_OUT" "T-01 mitigation 'handled by the framework' is not a mitigation"
assert_contains "$T_OUT" "T-02 has no mitigation"
assert_contains "$T_OUT" "T-03 mitigation 'rate limiting' is not a path:line, a story id or 'new story:'"
assert_contains "$T_OUT" "Gate: FAILED (3 problems)"
t_end

t_begin "a sensitive scope with zero threats fails"
d="$(tmpdir)/zero"; fixture "$d" "$SKIP"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "sensitive scope (payments, external input) with 0 threats"
assert_contains "$T_OUT" "Gate: FAILED (sensitive scope, 0 threats)"
t_end

t_begin "empty input fails: no model, or a model with no threats"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 threat models read"
fixture "$d" "$SKIP"; sed -i.bak 's/payments, external input/none/' "$d/docs/security/threat-model-webhook.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 threats read, nothing checked"
t_end

t_summary
