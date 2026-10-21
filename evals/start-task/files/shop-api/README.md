# ShopApi

The shop's one backend service: orders, totals and the order API that
ShopWeb calls. ShopWeb lives in its own repository beside this one.

## Working here

- Branches: `<type>/<ID>-<PascalName>` (feature, bugfix, hotfix, chore,
  docs) from `develop`; merge requests target `develop`.
- Gate: `make check`.
- Tasks are tracked as `SHOP-<n>`. A change that spans ShopApi and ShopWeb
  uses one task id in both repositories.
