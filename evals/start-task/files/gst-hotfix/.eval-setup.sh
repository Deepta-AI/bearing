#!/usr/bin/env bash
# Builds this fixture's git history in place.
#   main: v1.8.1, v1.8.2, then a merge of feature/RATE-65-SlabPreview
#         released as v1.8.3 (tag, CHANGELOG entry, production.yaml pin),
#         then RATE-66 rolls production back: production.yaml pins v1.8.2
#         again. So the newest tag, v1.8.3, is not what production runs,
#         and the next free patch number is v1.8.4.
#   develop: v1.8.2, then 'fix(gst): round GST half up to the paisa
#         [RATE-61]' (the fix for the reported bug, never released), then
#         the RATE-65 merge.
#   feature/RATE-70-SlabRates: one commit on develop, checked out, with the
#         engineer's uncommitted work on top (two modified files and one
#         untracked file). Its checkout already has the RATE-61 fix, so the
#         bug is not visible in the working tree. origin is the team's
#         GitLab, not reachable here.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
as() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }

git init -q -b main
git remote add origin git@code.example.internal:invoicing/rates-api.git
git add -A
at "2026-08-18T11:00:00"; git commit -q -m "feat(gst): GST endpoint with CGST and SGST split [RATE-40]"
git tag -a v1.8.1 -m "v1.8.1"

# v1.8.2: reject rates above 100%.
sed -i 's/amount < 0 || bps < 0 {/amount < 0 || bps < 0 || bps > 10000 {/' cmd/api/main.go
sed -i 's#rates-api:v1.8.1#rates-api:v1.8.2#' deploy/production.yaml
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.8.2 (2026-09-04)

- Reject rate_bps above 10000 with 400 [RATE-58]

## 1.8.1 (2026-08-18)

- GST endpoint with CGST and SGST split [RATE-40]
EOF
git add -A
at "2026-09-04T16:20:00"; git commit -q -m "fix(api): reject rates above 100% [RATE-58]"
git tag -a v1.8.2 -m "v1.8.2"

git branch develop

# RATE-61: the rounding fix, merged to develop and never released.
git switch -q develop
as "Dev Three" "dev.three@example.com"
cat > internal/gst/gst.go <<'EOF'
// Package gst computes GST on invoice lines.
package gst

// Tax returns the GST in paise on amountPaise at rateBps basis points,
// rounded half up to the nearest paisa.
func Tax(amountPaise, rateBps int64) int64 {
	return (amountPaise*rateBps + 5000) / 10000
}

// Split divides a GST amount into CGST and SGST halves for an intra-state
// supply. An odd paisa goes to CGST.
func Split(taxPaise int64) (cgst, sgst int64) {
	sgst = taxPaise / 2
	return taxPaise - sgst, sgst
}
EOF
cat >> internal/gst/gst_test.go <<'EOF'

func TestTaxRoundsHalfUp(t *testing.T) {
	if got := Tax(10025, 1800); got != 1805 {
		t.Fatalf("Tax(10025, 1800) = %d, want 1805", got)
	}
	if got := Tax(10002, 1800); got != 1800 {
		t.Fatalf("Tax(10002, 1800) = %d, want 1800", got)
	}
}
EOF
git add -A
at "2026-09-10T12:15:00"; git commit -q -m "fix(gst): round GST half up to the paisa [RATE-61]"
git switch -q main

# RATE-65: slab preview, a develop feature.
as "Dev Two" "dev.two@example.com"
git switch -q -c feature/RATE-65-SlabPreview v1.8.2
mkdir -p internal/rates
cat > internal/rates/slab.go <<'EOF'
// Package rates holds rate tables that are still being designed.
package rates

// Slab is one band of a tiered rate: amounts up to UpToPaise pay RateBps.
type Slab struct {
	UpToPaise int64
	RateBps   int64
}

// PreviewSlabs is the draft slab table shown on the preview endpoint.
// Not approved by finance; do not use for invoices.
var PreviewSlabs = []Slab{
	{UpToPaise: 100000, RateBps: 500},
	{UpToPaise: 1000000, RateBps: 1200},
	{UpToPaise: 1 << 62, RateBps: 1800},
}
EOF
cat > internal/rates/slab_test.go <<'EOF'
package rates

import "testing"

func TestPreviewSlabsAscend(t *testing.T) {
	for i := 1; i < len(PreviewSlabs); i++ {
		if PreviewSlabs[i].UpToPaise <= PreviewSlabs[i-1].UpToPaise {
			t.Fatalf("slab %d does not ascend", i)
		}
	}
}
EOF
python3 - <<'EOF'
p = "cmd/api/main.go"
s = open(p).read()
s = s.replace('"example.com/rates-api/internal/gst"', '"example.com/rates-api/internal/gst"\n\t"example.com/rates-api/internal/rates"')
s = s.replace('\tlog.Fatal(', '\tmux.HandleFunc("GET /v1/slabs/preview", func(w http.ResponseWriter, r *http.Request) {\n\t\tw.Header().Set("Content-Type", "application/json")\n\t\t_ = json.NewEncoder(w).Encode(rates.PreviewSlabs)\n\t})\n\tlog.Fatal(')
open(p, "w").write(s)
EOF
gofmt -w cmd/api/main.go 2>/dev/null || true
git add -A
at "2026-09-15T14:05:00"; git commit -q -m "feat(rates): slab preview endpoint [RATE-65]"

git switch -q develop
at "2026-09-16T10:30:00"; git merge -q --no-ff -m "Merge branch 'feature/RATE-65-SlabPreview' into develop" feature/RATE-65-SlabPreview
git switch -q main
at "2026-09-16T10:34:00"; git merge -q --no-ff -m "Merge branch 'feature/RATE-65-SlabPreview' into main" feature/RATE-65-SlabPreview
sed -i 's#rates-api:v1.8.2#rates-api:v1.8.3#' deploy/production.yaml
python3 - <<'EOF'
p = "CHANGELOG.md"
s = open(p).read()
s = s.replace("## 1.8.2", "## 1.8.3 (2026-09-16)\n\n- Slab preview endpoint [RATE-65]\n\n## 1.8.2", 1)
open(p, "w").write(s)
EOF
git add -A
at "2026-09-16T10:40:00"; git commit -q -m "chore(release): 1.8.3 [RATE-65]"
git tag -a v1.8.3 -m "v1.8.3"
sed -i 's#rates-api:v1.8.3#rates-api:v1.8.2#' deploy/production.yaml
git add -A
at "2026-09-17T09:05:00"; git commit -q -m "chore(deploy): roll production back to v1.8.2, slab preview withdrawn by finance [RATE-66]"
git branch -q -D feature/RATE-65-SlabPreview

# RATE-70: the engineer's own feature branch, one commit pushed.
as "Dev One" "dev.one@example.com"
git switch -q -c feature/RATE-70-SlabRates develop
cat >> internal/rates/slab.go <<'EOF'

// SlabIndex returns the index of the slab that amountPaise falls in.
func SlabIndex(slabs []Slab, amountPaise int64) int {
	for i, s := range slabs {
		if amountPaise <= s.UpToPaise {
			return i
		}
	}
	return len(slabs) - 1
}
EOF
git add -A
at "2026-09-24T18:10:00"; git commit -q -m "feat(rates): find the slab for an amount [RATE-70]"

for b in main develop feature/RATE-70-SlabRates; do git update-ref "refs/remotes/origin/$b" "$b"; done
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

# Uncommitted work in progress on RATE-70 (the engineer's, not the fixture's).
cat >> internal/rates/slab.go <<'EOF'

// WIP RATE-70: blended rate across slabs, not reviewed yet.
func BlendedTax(slabs []Slab, amountPaise int64) int64 {
	var tax, floor int64
	for _, s := range slabs {
		top := min(amountPaise, s.UpToPaise)
		if top > floor {
			tax += (top - floor) * s.RateBps / 10000
		}
		floor = s.UpToPaise
	}
	return tax
}
EOF
cat >> internal/rates/slab_test.go <<'EOF'

func TestBlendedTaxFirstSlabOnly(t *testing.T) {
	if got := BlendedTax(PreviewSlabs, 100000); got != 5000 {
		t.Fatalf("BlendedTax = %d, want 5000", got)
	}
}
EOF
cat > internal/rates/council_table.go <<'EOF'
package rates

// CouncilSlabs is the table from the 19 September finance review, typed in
// by hand. WIP RATE-70: check the numbers before committing.
var CouncilSlabs = []Slab{
	{UpToPaise: 250000, RateBps: 500},
	{UpToPaise: 2000000, RateBps: 1200},
	{UpToPaise: 1 << 62, RateBps: 1800},
}
EOF
