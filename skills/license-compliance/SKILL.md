---
name: license-compliance
description: 'Checks open-source licences: a CycloneDX SBOM, a licence inventory against an allow and deny policy, third-party notices. Use when asked for an "SBOM", "licence check", "third-party notices" or "which licences".'
argument-hint: "[sbom | licenses | notice | provenance | all] [--allow-unknown]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(syft:*), Bash(cyclonedx-npm:*), Bash(npx @cyclonedx/cyclonedx-npm:*), Bash(cyclonedx-gomod:*), Bash(cyclonedx-py:*), Bash(uv run cyclonedx-py:*), Bash(python3 scripts/license-gate.py:*), Bash(git log:*), Bash(git verify-commit:*), Bash(git config --get:*), Bash(make check:*)
---

# license-compliance

You ship other people's code. The SBOM says whose, the licence gate
says whether you may, the notice file says thank you in the form the
licence demands, and the provenance checklist says the build is what
the source says it is.

Not this: `dependency-audit` finds vulnerable and outdated packages; this
skill answers "may we ship it". `company-attribution` writes the repository's
own LICENSE.

## Inputs

- Mode: `$1`; if absent, `all`.
- Generator: the first installed of `syft` (any stack, `syft . -o
  cyclonedx-json`), `cyclonedx-npm` or `npx @cyclonedx/cyclonedx-npm`
  (`package.json`), `cyclonedx-gomod` (`go.mod`), `cyclonedx-py` or
  `uv run cyclonedx-py` (`pyproject.toml`). None installed: `sbom`
  stops with the install line per stack, and `licenses` runs on an
  existing `docs/compliance/sbom.cdx.json` when there is one.
- Stack: the manifest present; a monorepo runs one SBOM per manifest
  and merges the component lists.
- Policy: `docs/compliance/license-policy.yml`; if absent, copied from
  `templates/license-policy.yml` and the report says the defaults are
  in force (permissive allowed, copyleft denied, unknown fails).
- Gate script: `templates/license-gate.py` installed as
  `scripts/license-gate.py`; needs only Python 3, no packages.
- Templates: `templates/NOTICE-THIRD-PARTY.md` (to the repository
  root), `templates/provenance-checklist.md` (to
  `docs/compliance/provenance.md`), `templates/licenses.md` (to
  `docs/compliance/licenses.md`).

## Steps

1. `sbom`: run the generator into `docs/compliance/sbom.cdx.json`
   (create the directory). Print "sbom: N components, generator
   <name> <version>, K without a licence field". N=0: stop with "0
   components; wrong directory or lockfile missing". Commit the SBOM
   with the lockfile; it changes when the lockfile changes.
2. `licenses`: install the gate script when absent, then `python3
   scripts/license-gate.py docs/compliance/sbom.cdx.json
   docs/compliance/license-policy.yml`. It prints "licenses: N
   components, allowed A, denied D, unknown U" and exits non-zero on
   N=0, D>0, or U>0 (unless `--allow-unknown`). Write
   `docs/compliance/licenses.md` from `templates/licenses.md` with one
   row per component. Every denied component is a line in Not done
   with the two ways out: replace it, or a written exception in the
   policy's `exceptions:` with owner and reason. Add a `licenses` CI
   job and a `make licenses` target that run the same command.
3. `notice`: for every component whose licence requires attribution
   (MIT, BSD, Apache-2.0, ISC and the like; the gate marks them), write
   the name, version, licence and copyright line into
   `NOTICE-THIRD-PARTY.md` from the template. Print "notice: N
   components attributed, C missing a copyright line" and list the C
   for a hand fill from the package's LICENSE file.
4. `provenance`: fill `docs/compliance/provenance.md` from the
   checklist by reading the repository: `git log --show-signature -5`
   for signed commits and `git config --get commit.gpgsign`; a
   lockfile committed; a pinned toolchain (`go.mod` `toolchain`,
   `.nvmrc` or `packageManager`, `.python-version`); a CI build from a
   clean checkout; `SOURCE_DATE_EPOCH` or the stack's reproducible flag
   (`-trimpath`, `npm ci`, `uv sync --frozen`); the SBOM attached to the
   release; an image digest, not a tag, in the deploy. Print
   "provenance: N items, met M, unmet K" with the fix line per unmet.
5. `all`: steps 1 to 4 in order; a stop in step 1 stops the run.
6. Print the contract.

## Output contract

```
## Compliance: <mode>
SBOM: docs/compliance/sbom.cdx.json, N components, generator <name> <version>, no licence field K
Licences: N components, allowed A, denied D, unknown U -> <pass | fail>   policy docs/compliance/license-policy.yml
  denied: <component@version> <licence>; ...
CI: job licenses <added | present>, make licenses <added | present>
Notice: NOTICE-THIRD-PARTY.md, N attributed, C missing copyright (<list>)
Provenance: docs/compliance/provenance.md, N items, met M, unmet K
Not done: <list> | none
```

## Gotchas

- An SBOM from the source tree without the lockfile lists what the
  manifest asks for, not what ships. Generate from the lockfile or the
  built artefact, and say which.
- "Unknown" licence is not "probably fine". It fails the gate until a
  person reads the package and writes the exception.
- Dual-licensed packages (`MIT OR GPL-2.0`) are allowed when one side
  is allowed; `MIT AND GPL-2.0` is denied when either side is. The gate
  parses the expression; a hand check does not.
- Copyleft in a dev dependency that never ships is usually fine, but
  the SBOM does not know what ships. Mark scope in the policy
  (`dev: allow`) and keep the runtime list strict.
- Apache-2.0 requires the NOTICE file's contents to be carried, not
  just the licence name. The attribution step copies it.
- A signed tag on an unsigned history proves the tag, not the code.
  The checklist asks for both.
- Container base images carry their own licences; `syft` on the image
  catches them, the manifest generators do not.
