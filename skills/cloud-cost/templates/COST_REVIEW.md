# Cost review: <YYYY-MM>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. A cost review
     covers the previous full month, never the running one; the engineer and
     the budget owner read it, and it changes nothing: every action is a
     printed command. Saved as docs/cost/COST_REVIEW-<month>.md. -->

Source: <csv path | aws ce | gcloud export | az consumption | pasted>   Lines: <N>   Basis: unblended | blended | amortised | unknown
Total: <currency> <amount>   Previous month: <amount> (<delta>%) | first review
Reviewed: <YYYY-MM-DD>   Owner: <rotation>   Next review: <YYYY-MM-DD>

## Attribution

<!-- What: how much of the spend maps to a service and an environment, by
     count and amount, and what is left unattributed.
     Good: matched from tags or labels first, then resource names against
     terraform/, k8s/ and helm/; the rest counted as unattributed, never
     guessed. Unattributed above 20 percent is finding one: name the tags to
     add and print the tagging command with the resource ids.
     Example: "environment | 71% | 29% | USD 1,840" then "Tags to add: env on
     14 EC2 instances. Command: aws resourcegroupstaggingapi tag-resources ..." -->

| Key | Attributed | Unattributed | Amount unattributed |
| --- | --- | --- | --- |
| service | <a>% | <c>% | <amount> |
| environment | <b>% | <d>% | <amount> |

Tags to add: <list | none>. Command: `<tagging command>`

## Top ten spend lines

<!-- What: the ten largest billing lines of the month by amount.
     Good: each line is a SKU or resource id from the source, with its share
     of the total and the month-over-month delta from the previous review
     ("first review" when there is none); a lump from a commitment purchase
     is called out, not read as growth.
     Example: "| 1 | db.r6g.xlarge orders-prod | RDS | prod | USD 2,310 | 18% | +4% |" -->

| # | Line (SKU or resource) | Service | Env | Amount | % of total | MoM |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |

## Unit economics

<!-- What: what one request, one tenant and one job cost this month.
     Good: every denominator names its source (docs/observability/slos.md, a
     pasted metric, the user) or the Cost cell says "denominator unknown";
     cost per request is prod compute plus stores over monthly requests.
     Example: "| per 1000 requests | prod compute + stores | 41.2 M requests
     (slos.md, gateway request rate) | USD 0.21 |" -->

| Unit | Numerator | Denominator (source) | Cost |
| --- | --- | --- | --- |
| per 1000 requests | prod compute + stores | <requests> (<slos.md | metric>) | <x> or denominator unknown |
| per tenant | prod total | <n> active tenants (<source>) | <x> |
| per job | worker cost | <n> jobs (<source>) | <x> |

## Cuts (proposals; engineer runs the command)

<!-- What: savings proposals, one per row, each with the command the
     engineer runs; the skill never runs it.
     Good: evidence is a line or metric (idle means under 5 percent CPU for
     14 days; over-provisioned means a limit above 3x the p95 use); the risk
     cell is filled on every row; the command carries the resource id; no
     committed use until the prod baseline has been stable three months.
     Without cluster access the row reads "check utilisation" with the
     kubectl top command. Replace or delete the sample rows below.
     Example: "| idle instance i-0a41f2 | 2% CPU over 14 d | USD 96 | none if no
     traffic | `aws ec2 stop-instances --instance-ids i-0a41f2` |" -->

| Cut | Evidence (line, metric) | Saving/month | Risk | Command |
| --- | --- | --- | --- | --- |
| idle instance <id> | 2% CPU over 14 d | <amount> | none if no traffic | `<stop or terminate command>` |
| unattached volume <id> | no attachment | <amount> | data on the volume: snapshot first | `<snapshot then delete>` |
| over-provisioned <deploy> | limit 4 CPU, p95 use 0.6 | <amount> | throttling at peak: watch p95 | `kubectl set resources ...` |
| log retention <sink> | no retention, <GB>/month | <amount> | audit needs: keep audit sink | `<set retention 30 d>` |
| non-prod schedule | dev and qa 24x7 | <amount> (about 65%) | morning warm-up | `<scheduler command>` |
| egress <pair> | cross-zone <GB> | <amount> | none | `<co-locate>` |

Total estimated: <amount>/month across <K> proposals.

## Cost table (copied into docs/architecture/deployment.md section 10)

<!-- What: monthly cost per component per environment, the table that
     replaces the "Cost (placeholder)" section of deployment.md.
     Good: every cell traces to a billing line named in Source; when
     deployment.md is absent the table lives only here and the contract
     says "in the review only".
     Example: "| orders-api | USD 38 | USD 52 | USD 610 | AmazonECS, tag
     service=orders-api |" -->

| Component | dev | qa | prod | Source |
| --- | --- | --- | --- | --- |
| | | | | <billing line> |

## Cadence and alerts

<!-- What: when the next review happens, who runs it, and the budget alerts.
     Good: first working week of the month with an owner rotation, not a
     named person; the budget is last month plus 10 percent with alerts at
     50, 80 and 100 percent; the budget command is printed, never run.
     Example: "- Budget: USD 14,100 (last month USD 12,820 + 10%). Alerts at
     50, 80, 100%." -->

- Review: first working week of each month, owner <rotation>.
- Budget: <amount> (last month + 10%). Alerts at 50, 80, 100%.
- Command: `<aws budgets create-budget ... | gcloud billing budgets create ...>`

## Decisions

<!-- What: what was decided on each cut, filled after the review with the
     budget owner.
     Good: one row per proposal in Cuts: accepted, rejected with the reason,
     or deferred to a date; an owner and a ticket key for accepted ones.
     Example: "| non-prod schedule | accepted, from 1 Nov | platform rotation |
     OPS-212 |" -->

| Proposal | Decision | Owner | Ticket |
| --- | --- | --- | --- |
