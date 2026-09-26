# Provenance checklist

<!-- Template guidance: this checklist says whether the build is what the
     source says it is; it is read by the release approver and by a customer's
     security review. It has no sections: fill the table by reading the
     repository (git log --show-signature, git config, the lockfile, the CI
     file, the deploy manifest). Delete this comment when you fill it.
     Good: the Evidence cell names what was read and what it showed (a
     command and its result, a file:line); Met is yes or no, so the counts add up;
     every unmet item keeps its fix line. The counts line matches the rows.
     A signed tag on unsigned history meets item 2, not item 1.
     Example: | 3 | Lockfile committed and used | `package-lock.json` tracked; `.gitlab-ci.yml:24` runs `npm ci` | yes | | -->

Reviewed: <YYYY-MM-DD> by <name>. Items: <N>, met <M>, unmet <K>.

| # | Item | Evidence | Met | Fix when unmet |
| --- | --- | --- | --- | --- |
| 1 | Commits on the default branch are signed | `git log --show-signature -5`, `commit.gpgsign=true` | | enable signing; require signed commits on the protected branch |
| 2 | Tags are signed | `git tag -v <tag>` | | sign tags in the release procedure |
| 3 | Lockfile committed and used (`npm ci`, `uv sync --frozen`, Go module sums) | lockfile in the tree, CI uses the frozen install | | commit the lockfile; switch CI to the frozen install |
| 4 | Toolchain pinned | `go.mod toolchain`, `.nvmrc` or `packageManager`, `.python-version` | | add the pin file |
| 5 | Build from a clean checkout in CI | CI job clones fresh, no cache of build outputs | | disable output caching for the release job |
| 6 | Reproducible build flags | `-trimpath -ldflags=-buildid=`, `SOURCE_DATE_EPOCH`, deterministic archives | | add the flags; compare two builds' checksums |
| 7 | Two builds of the same commit produce the same checksum | two CI runs, `sha256sum` equal | | fix whichever input differs (timestamps, paths, ordering) |
| 8 | SBOM generated in CI and attached to the release | `docs/compliance/sbom.cdx.json` in the release assets | | add the sbom step to the release job |
| 9 | Artefacts referenced by digest, not tag, in deploy | image `@sha256:` in the deploy manifest | | pin the digest at release time |
| 10 | Release artefacts signed or attested | a signature or a provenance attestation on each artefact | | add signing to the release job |
| 11 | Dependencies fetched from a pinned registry over TLS | registry URL in the lockfile or config | | pin the registry |
| 12 | No build step downloads and runs unpinned scripts | grep of CI and Makefile for a piped shell install | | vendor or pin by checksum |
