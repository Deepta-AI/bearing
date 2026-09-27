# Contributing

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:` ...). A change that breaks
API consumers carries a `BREAKING CHANGE:` footer describing the migration.

## Releases

- Releases are cut from `main` and tagged `vX.Y.Z` (annotated). The release
  engineer tags and deploys; the tag triggers the image build.
- Every release gets a section in CHANGELOG.md.
- Hotfixes are branched from the release tag as `hotfix/X.Y.Z`, tagged
  there, and must be merged back into `main` before the next release is
  cut from `main`.
