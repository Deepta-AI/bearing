---
name: cloud-cost
description: 'Reviews the cloud bill read-only: spend by service and environment, top ten lines, cost per request, proposed cuts. Use when asked about the "cloud bill", "cost review", "FinOps" or "why is the bill so high".'
argument-hint: "[--csv <billing export>] [--month YYYY-MM] [--provider aws|gcp|azure|other]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(python3 -c:*), Bash(aws ce get-cost-and-usage:*), Bash(gcloud billing:*), Bash(az consumption usage list:*), Bash(kubectl top:*), Bash(kubectl get:*)
---

# cloud-cost

The bill is a table nobody reads until it doubles. This skill reads it
monthly, attributes every line to a service and an environment, prices a
request, and hands the engineer the cuts as commands.

Not this: `deployment-architecture` writes the topology and leaves
the cost table as a placeholder; this skill fills it. `infra`
changes infrastructure; this skill never does.

## Inputs

- billing lines: `--csv`, any export whose header has a cost column
  (`cost|amount`), a service column (`service|product|sku`) and a
  grouping column (`project|account|tag|label|environment`); if absent,
  the provider CLI for the month: `aws ce get-cost-and-usage
  --time-period Start=<m-01>,End=<next-01> --granularity MONTHLY --metrics
  UnblendedCost --group-by Type=DIMENSION,Key=SERVICE` (again with
  `Type=TAG,Key=env`), `gcloud billing accounts list` then the BigQuery
  export (the CLI has no line items; the CSV is the route), `az
  consumption usage list --start-date <m-01> --end-date <last>`; none
  usable: ask once for the top ten lines pasted from the console; nothing:
  stop with "no billing source: pass --csv or paste the top ten".
- month: `--month`; default the previous full month
  (`date -d "-1 month" +%Y-%m`).
- attribution keys: `service`, `env` or `environment`, `team` tags or
  labels in the data; if absent, resource names matched to `terraform/`,
  `k8s/`, `helm/` labels; still unmatched: `unattributed`, counted.
- denominators: requests from `docs/observability/slos.md` or a pasted
  metric; tenants and jobs from the user; absent: `denominator unknown`.
- utilisation for over-provisioning: `kubectl top pods` and `kubectl get
  deploy -o yaml` requests when a cluster is reachable; absent: the cut
  is listed as "check utilisation" with the command.
- deployment doc: `docs/architecture/deployment.md` section "Cost
  (placeholder)"; present: filled; absent: the table lives in the review.
- previous review: `docs/cost/COST_REVIEW-<prev>.md` for month-over-month;
  absent: the MoM column says `first review`.
- template in this skill: `templates/COST_REVIEW.md`.

## Steps

1. Load the lines with `python3 -c` (csv module). Print "N lines,
   <currency> <total> for <month> from <source>; cost basis <unblended |
   blended | amortised | unknown>". Zero lines: stop non-zero.
2. Attribute each line to service and environment. Print attributed
   against unattributed by count and amount. Unattributed above 20
   percent of spend is finding one: the tag names to add and the
   command to add them (`aws resourcegroupstaggingapi tag-resources`,
   `gcloud ... update --update-labels`), printed.
3. Top ten lines by amount with percent of total and MoM delta.
4. Unit economics: cost per 1000 requests (prod compute plus stores over
   monthly requests), per tenant (prod total over active tenants), per
   job (worker cost over jobs). Every denominator names its source or
   the line says `denominator unknown`.
5. Cuts, each with evidence, monthly saving, risk and the command for
   the engineer, never run: idle (instances under 5 percent CPU for 14
   days, unattached volumes, unused addresses, snapshots older than the
   retention, load balancers with no targets); over-provisioned (limit
   above 3x the p95 use from `kubectl top`); unbounded logs (ingestion
   with no retention: set 30 days, drop debug in prod); egress
   (cross-zone and NAT traffic: co-locate chatty pairs); non-prod off
   overnight and at weekends (about 65 percent of dev and qa compute);
   committed use for the prod baseline only after three stable months.
   Print the count and the summed estimate. Each cut also gets a row in
   the review's Decisions table once the owner answers: accepted (with an
   owner and a task id), deferred (with a date) or declined (with the
   reason), so next month's review starts from them.
6. Fill the cost table (component by dev, qa, prod, with the billing
   line as source) in `deployment.md` when present; else in the review.
7. Cadence: review in the first working week, owner a rotation; budget
   alerts at 50, 80 and 100 percent of last month plus 10 percent, with
   `aws budgets create-budget` or `gcloud billing budgets create` printed.
8. Write `docs/cost/COST_REVIEW-<month>.md` from `templates/COST_REVIEW.md`
   and print the contract.

## Output contract

```
## Cost review: <month> (<source>, N lines, <currency> <total>, <basis>)
Attributed: <a>% by service, <b>% by environment; unattributed <c>% (<amount>)
| # | Line | Service | Env | Amount | % | MoM |
...
Unit: <x>/1000 req (<requests>, <source>), <x>/tenant (<n>), <x>/job (<n>) | denominator unknown
Cuts: K proposals, est. <amount>/month
| Cut | Evidence | Saving/month | Risk | Command |
...
Deployment cost table: filled in docs/architecture/deployment.md | in the review only
Cadence: first working week, owner <rotation>; budget alerts 50/80/100% (command printed)
Path: docs/cost/COST_REVIEW-<month>.md
```

## Gotchas

- Never changes infrastructure, deletes a resource or creates a budget.
  Every action is a printed command with the resource id.
- Unblended, blended and amortised differ; say which the source uses.
  A commitment purchase lands as a lump on one day in some views.
- The current month is incomplete and last month can be restated for
  days; review the previous full month, never the running one.
- A cut that saves 3 percent and adds an outage is not a cut; the risk
  column is filled for every row.
- Committed use bought before the workload is stable locks in the waste.
- Egress and logs grow silently; check them every month even when small.
- Cost per request without a request count is a guess; the denominator
  has a source or the line says unknown.
- The billing CLI runs on the engineer's session; the skill never asks
  for keys and never prints an account id it did not read from a file.
