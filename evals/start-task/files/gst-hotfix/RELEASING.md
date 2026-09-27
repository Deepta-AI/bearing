# Branches and releases

- `develop` is the integration branch. feature and bugfix branches start
  from it and merge back into it.
- `main` is always exactly what production runs: every merge to main is a
  release, gets a `vX.Y.Z` tag and a CHANGELOG entry, and the tag is what
  deploy/production.yaml pins.
- Branch names: `<type>/<TICKET>-<ShortName>`, type one of feature,
  bugfix, hotfix, chore; ticket id in capitals; ShortName in PascalCase.

## Hotfix

1. Branch `hotfix/<TICKET>-<ShortName>` from main.
2. Fix it with a regression test, bump the patch version in CHANGELOG.md.
3. Merge into main, tag, deploy.
4. Merge main back into develop so the fix is not lost at the next release.
