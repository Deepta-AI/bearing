# checkout-api

The checkout service: basket, payment intent and order confirmation.

- `make check` runs lint and the tests.
- Deploys go through the GitLab pipeline; the engineer on the release
  rotation runs the deploy job. Environments are listed in
  docs/environments.md.
- After every qa deploy, run `make seed-qa`: it POSTs the demo baskets
  the product team uses for their walkthroughs to the qa API.
- Past verification notes live in docs/releases/.
