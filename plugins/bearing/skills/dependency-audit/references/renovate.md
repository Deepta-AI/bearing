# dependency-audit: fitting renovate.json to the repository

Read when you write or refresh Renovate config (step 7).

7. Renovate, only with `--renovate` or when the request asks for it;
   otherwise skip and say "Renovate: not requested". Write or refresh
   `renovate.json` from `templates/renovate.json`, keeping any
   `packageRules` the repo added, and fit it to the repository:
   the template names no `baseBranches`, so Renovate uses the default
   branch; add one only for a branch that exists (`git branch -a`),
   never an assumed `develop`; the manager blocks and `packageRules`
   are only those of the detected stacks (drop terraform, expo, android and the rest when
   the repo has none), every hold from Inputs becomes an
   `allowedVersions` rule naming its ADR, and a repository whose modules
   come from an offline or internal mirror gets a note that Renovate
   needs the same registry (`hostRules` or `registryUrls`) to see them.
   `python3 -c "import json; json.load(open('renovate.json'))"`.
