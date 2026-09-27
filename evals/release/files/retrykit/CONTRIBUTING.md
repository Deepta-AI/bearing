# Contributing

Commits follow Conventional Commits.

## Publishing

1. Update CHANGELOG.md and the version in package.json.
2. Tag the release on main as `vX.Y.Z`.
3. Publish from your machine with the team token in `.env.local`:
   `npm publish --provenance`. Every release is published with npm
   provenance so consumers can verify where it was built.
