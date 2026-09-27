---
name: license-compliance
description: 'Checks open-source licences: a CycloneDX SBOM, a licence inventory against an allow and deny policy, third-party notices. Use when asked for an "SBOM", "licence check", "third-party notices" or "which licences".'
argument-hint: "[sbom | licenses | notice | provenance | all] [--allow-unknown]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(cp:*), Bash(syft:*), Bash(cyclonedx-npm:*), Bash(npx @cyclonedx/cyclonedx-npm@6.0.1:*), Bash(cyclonedx-gomod:*), Bash(cyclonedx-py:*), Bash(uv run cyclonedx-py:*), Bash(python3 scripts/license-gate.py:*), Bash(go version -m:*), Bash(go list:*), Bash(go env GOROOT:*), Bash(git log:*), Bash(git status:*), Bash(git verify-commit:*), Bash(git config --get:*), Bash(make check:*), Bash(make build:*)
---

# license-compliance

You ship other people's code. The question is never "which licences are
in the tree" but "what do we hand to whom, and what does each licence
demand of that act". Distribution triggers most obligations; what does
not ship mostly does not matter; and a notice file is only one of the
duties a licence can carry.

Not this: `dependency-audit` finds vulnerable and outdated packages; this
skill answers "may we ship it". `company-attribution` writes the repository's
own LICENSE.

## Inputs

- Mode: `$1`; if absent, infer it from the request (a gate or check:
  `licenses`; notices for a customer: `notice`; `all` only when asked).
  Do only what the mode needs: a notices request does not get a gate,
  policy, SBOM or Makefile target added to the repository.
- What ships, and how: read the Dockerfile, release or distribution docs,
  ADRs, the Makefile build line and the CI image job. Record the delivery
  form (image, binary or bundle to customers; hosted only; source
  shipped), the dev exclusion (`npm ci --omit=dev`, a multi-stage build,
  a build of one main package) and the linking (static
  `CGO_ENABLED=0`, dynamic, bundled JS). Every verdict cites this.
- Inventory source, best first: the built artefact (`syft` on the image,
  `go version -m bin/<name>`), then the lockfile, never the manifest
  alone. With no generator and no `node_modules`, read the lockfile
  directly: an npm v2/v3 `package-lock.json` carries `license`, `dev`
  and the nested tree, and the gate reads it as is. A v1 lockfile,
  `uv.lock` or `poetry.lock` carries no licences: say so and read each
  package's metadata or LICENSE by hand. Go: `go list -deps -f
  '{{if not .Standard}}{{.Module}}{{end}}' ./cmd/<name>` (test imports
  excluded), with `GOFLAGS=-mod=vendor` when `vendor/` exists.
- Generators, when an SBOM is wanted: `syft . -o cyclonedx-json`,
  `cyclonedx-npm` or `npx @cyclonedx/cyclonedx-npm@6.0.1`,
  `cyclonedx-gomod`, `cyclonedx-py` or `uv run cyclonedx-py`. A missing
  one is not a stop: note its install line and continue from the lockfile.
- Policy: `docs/compliance/license-policy.yml`; if absent, copied from
  `templates/license-policy.yml`, and the report says the defaults (for a
  proprietary product distributed without source) are in force.
- Gate: `templates/license-gate.py` copied to `scripts/license-gate.py`;
  Python 3 only. It reads a CycloneDX SBOM or an npm lockfile.

## Steps

1. Establish what ships (Inputs). If nothing is distributed (hosted
   only), say which obligations fall away (GPL, LGPL, attribution) and
   which do not (AGPL-3.0 and SSPL on network use, BUSL on use).
2. Inventory. List every third-party component in the resolved tree
   with name, exact version, declared licence, scope and, for a
   transitive one, the direct dependency that pulls it in. Exclude the
   product itself (the lockfile's root `""` entry, the main module).
   Print the count with its runtime and dev split, and check the split
   adds up to the lockfile's entries minus the root.
3. Judge each component against the policy (the gate does the
   arithmetic; read its reasons). Scope comes from what the build
   installs, not from which list in `package.json` names a package: one
   in `devDependencies` that a runtime package also requires has no
   `dev` flag and ships; `devOptional` ships under `--omit=dev`. Then the
   traps the gate cannot see; read the package, not only the field:
   - the locked version's licence, not the project's reputation: projects
     relicense between majors (MIT to BUSL, Apache to SSPL); a README or
     an old audit that says otherwise is stale, and the report says so;
   - `UNLICENSED` is npm's "no licence granted" (proprietary, often from a
     vendor registry: read `resolved`); it is not `Unlicense`. Shipping it
     needs the vendor's redistribution terms;
   - no licence field, `SEE LICENSE IN`, or a README line with no licence
     file: unresolved until a person reads the package; never assume MIT;
   - an OR expression is a choice: record which branch you rely on;
   - a transitive blocker is fixed through its parent (replace or pin the
     parent, or an override), never by editing the child alone.
4. `licenses` (a gate): `python3 scripts/license-gate.py package-lock.json
   docs/compliance/license-policy.yml` (or the SBOM path). It prints the
   count, and fails on zero components, on a runtime denied or unknown,
   and on dev ones only under `dev: check`. Set `dev:` from what step 1
   proved, with the evidence in a comment. Add a CI job of its own that
   runs the same command offline against the committed lockfile (or
   regenerates the SBOM inside the job; a committed derived file goes
   stale), and a `make licenses` target running it when there is a
   Makefile. Do not fold it into an existing test target or job, which
   would then go red on a licence finding. Run it once and show the
   output. Write `docs/compliance/licenses.md` from `templates/licenses.md`
   only when an inventory file is wanted.
5. `notice`: bring the file the distribution already ships (the path the
   release docs name) up to date; one file only. Take the component list
   from what is compiled or installed into the delivered artefact, so
   stale rows go and test-only modules stay out. For each component:
   - the copyright lines from its LICENSE, its NOTICE and the headers of
     its shipped source files; grep them (`Copyright`, `derived from`,
     `Portions`, `SPDX-License-Identifier`): a vendored file adapted from
     another project carries that project's copyright and licence too;
   - the full licence text once per distinct licence, and every holder's
     line (MIT and BSD texts are per holder);
   - an Apache-2.0 component's NOTICE file verbatim, including the third
     parties it credits;
   - the language runtime linked in: a Go binary contains the standard
     library and runtime (BSD-3-Clause; take the text and "Copyright 2009
     The Go Authors" from `$(go env GOROOT)/LICENSE`); Rust std is MIT OR
     Apache-2.0; an image's Node comes with the base image's notices;
   - LGPL: the LGPL text plus the GPL text it builds on (LGPL-3.0 4(b)),
     and a prominent notice that the library is used under it (4(a));
   - a component with no licence file: write what it declares, mark the
     text as missing and list it for its authors; never paste another
     package's licence text or invent a holder.
   A notices file lists and credits; it never states that the release is
   compliant. If it names separate licence files, they must ship in the
   same tarball or image; otherwise keep the texts in the one file.
6. Obligations beyond a notice, in the final message: LGPL in a static
   binary shipped without source needs the customer to be able to relink
   against a modified library (the product's object files or source, the
   library's source or a written offer; LGPL-3.0 sections 4(d) and 6);
   GPL or AGPL in a distributed artefact puts the combined work's source
   on offer; BUSL forbids the production use its Additional Use Grant
   excludes. Give the ways out as options (replace; dynamic linking or a
   separate process where the licence allows; provide what it requires;
   a commercial licence) and name who has to decide.
7. `provenance` (only when asked): fill `docs/compliance/provenance.md`
   from `templates/provenance-checklist.md` by reading the repository
   (`git log --show-signature -5`, `git config --get commit.gpgsign`,
   committed lockfile, pinned toolchain, clean CI build, reproducible
   flags such as `-trimpath`, `npm ci` or `uv sync --frozen`, SBOM
   attached, image digest). Print met and unmet, with a fix
   line for each unmet.
8. Leave dependency files, source, the Dockerfile and the build
   unchanged; run the repository's own check (`make check`) and show it
   still passes. Do not commit.

## Output contract

```
## Licence compliance: <mode>
Ships: <artefact> to <whom>, <linking>, dev excluded by <evidence>
Inventory: N third-party (R runtime, D dev) from <lockfile | SBOM | binary>
Verdict: <may ship | may not ship as is>
  blockers: <name@version licence, via <parent>, why>; ...
  unresolved: <name@version, what a person must read>; ...
Gate: <command> -> exit <code>, "<its count line>"   CI job <name> <added | present>
Notices: <file>, N components + <runtime>, missing texts <list | none>
Obligations beyond notices: <list | none>
Decisions for a person: <list>
Ran: <commands that ran>   Not run: <CI pipeline, absent generators, ...>
```

## Gotchas

- The gate's zero-component failure and printed count are the only proof
  it looked. A check that passes on an empty or missing lockfile is
  worse than none.
- Exceptions name one version (`name@version`); a bare name exempts
  every future release, including a relicensed one. Only a person who
  read the package writes one, with owner and date; never to make a gate
  pass.
- `dev: allow` holds only for the build you inspected. If the image runs
  `npm ci` without `--omit=dev`, or a second artefact (a CLI, a desktop
  bundle) ships dev tooling, dev is not dev.
- A front-end bundle ships every runtime dependency to every browser, and
  a minifier that strips comments strips the licence headers; the
  notices file is where attribution survives.
- Container base images carry their own licences (GPL userland in Debian
  and Alpine); `syft` on the image lists them, the lockfile does not.
- Go: `vendor/modules.txt` and `go.mod` also list test-only and
  other-platform modules; `go version -m` on the built binary is what
  shipped. LGPL projects often put the copyright line only in source
  headers; it still goes in the notices.
- Apache-2.0 4(d) requires the NOTICE contents, not the licence name. MIT
  and BSD require the copyright line and text in binary distributions too.
- A nested `node_modules/a/node_modules/b` is a second copy, often another
  version, and ships as well; count and judge it.
- A signed tag on an unsigned history proves the tag, not the code.
