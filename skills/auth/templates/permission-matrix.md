# Permission matrix: <scope>

<!-- Template guidance: delete this comment when you fill the matrix. The
     matrix is a test table: roles by resource by action, one row per cell,
     read by reviewers and generated into the table-driven test.
     Good: every row names a test `TC-AUTH-<role>-<resource>-<action>` and
     the cell count equals the test count; a resource the caller may not
     know exists answers 404, not 403, because 403 confirms the row; the
     cross-tenant column appears only when the schema has a tenant or org
     column. Replace the four sample rows below with your own.
     Example: "| support | ticket | update | cross-tenant | 404 |
     TC-AUTH-support-ticket-update-cross |" -->

One row per cell. `Expected` is the HTTP status (or the app's error
class) for that role acting on a resource it does not own, unless the
row says `own`. Every row has a test named `TC-AUTH-<role>-<resource>-<action>`.

Roles: <role list>. Resources: <resource list>. Tenant column present: <yes/no>.

| Role | Resource | Action | Own / other / cross-tenant | Expected | Test |
| --- | --- | --- | --- | --- | --- |
| anonymous | order | read | other | 401 | TC-AUTH-anonymous-order-read |
| customer | order | read | own | 200 | TC-AUTH-customer-order-read-own |
| customer | order | read | other | 404 | TC-AUTH-customer-order-read-other |
| admin | order | read | cross-tenant | 404 | TC-AUTH-admin-order-read-cross |

Cells: <N>. Tests: <N>. These two numbers are printed by the suite and must match.
