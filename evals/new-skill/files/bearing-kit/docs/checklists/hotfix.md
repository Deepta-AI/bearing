# Hotfix checklist (payments team)

Shared by the payments team; we would like every team to get this as a
skill so steps stop getting skipped.

1. Open a PAY- ticket. Hotfixes are for SEV1 and SEV2 only.
2. Branch from the tag that is in production:
   `git checkout -b hotfix/PAY-<n> v<X.Y.Z>`
3. Cherry-pick the fix from main: `git cherry-pick -x <sha>`. If it does
   not apply cleanly, write the fix on the hotfix branch and open a
   follow-up MR to main so main does not regress.
4. Bump the patch version in the VERSION file (X.Y.Z to X.Y.Z+1).
5. CI takes about 40 minutes. If the fix is small, put `[skip tests]` in
   the commit message to skip the test stage.
6. Push and tag:
   `git push origin hotfix/PAY-<n> && git tag v<X.Y.Z+1> && git push origin v<X.Y.Z+1>`
7. Deploy: `make deploy-prod HOST=deploy.acme-pay.internal`
8. Post in #pay-hotfix with the ticket link and the new tag.
9. Merge the hotfix branch back into main.
