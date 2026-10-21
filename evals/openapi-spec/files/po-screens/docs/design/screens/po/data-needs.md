# Data needs: po

## S-01 Purchase orders

### Fields

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-01 | order.number | string | server | new |
| F-02 | order.status | enum | server | new |
| F-03 | order.total | integer | server | new |

### Actions

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-01 | List orders | list the company's orders, newest first, 50 per page, filtered by status | 200 page of orders | new |

### States

| State | Server condition |
| --- | --- |
| loading | the list request is in flight |
| empty | the list returns zero orders |
| error | the list call fails with a 5xx or a timeout |

## S-02 New purchase order

### Fields

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-04 | line.quantity | integer | client: the S-02 line form | new |

### Actions

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-02 | Save draft | create a draft order, safe to retry after a network drop | 201 created; 422 quantity_out_of_range | new |

### States

| State | Server condition |
| --- | --- |
| loading | the create call is in flight |
| error | the create call fails with a 5xx or a timeout |
| error: quantity_out_of_range | the create call returns 422 quantity_out_of_range |

## S-03 Purchase order

### Fields

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-05 | order.lines | list | server | new |

### Actions

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-03 | Open order | read one order of the caller's company | 200 order; 404 not_found | new |
| A-04 | Submit | submit a draft for approval | 200 submitted; 409 not_a_draft | new |
| A-05 | Approve | approve a submitted order | 200 approved; 403 forbidden_self_approval | new |
| A-06 | Cancel | cancel a draft or submitted order | 200 cancelled | new |

### States

| State | Server condition |
| --- | --- |
| loading | the order request is in flight |
| error: forbidden_self_approval | the approve call returns 403 forbidden_self_approval |
| error | the order call fails with a 5xx or a timeout |
