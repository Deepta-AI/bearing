# GenAI solution: invoice extraction

Status: Reviewed

## Problem
Suppliers email PDF invoices to the support inbox; agents retype the
fields into the payables system.

## Task and approach
extract, structured output. One call per invoice with the JSON schema
below; no tools, no retrieval.

## Model and budget
| Item | Value |
| --- | --- |
| Tier | balanced (`claude-sonnet-5`) |
| Volume | about 25,000 invoices a day |
| Tokens in per request | 2,800 (system 600, invoice text 2,200) |
| Tokens out per request | 250 |
| Timeout | 30 s |
| Cacheable | yes: the same invoice text gives the same fields |

## Output schema
```json
{
  "type": "object",
  "required": ["supplier_name", "invoice_number", "invoice_date", "currency", "total_amount"],
  "properties": {
    "supplier_name": {"type": "string"},
    "invoice_number": {"type": "string"},
    "invoice_date": {"type": "string", "format": "date"},
    "currency": {"type": "string", "enum": ["INR", "GBP", "USD", "EUR"]},
    "total_amount": {"type": "number"}
  },
  "additionalProperties": false
}
```

## Fallback
None at launch; on failure the invoice goes to the manual queue.
