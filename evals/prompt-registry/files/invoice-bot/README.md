# invoice-bot

Accounts payable inbox automation for Ferncrest Foods. Emails arriving in
the AP inbox are classified (invoice, credit note, statement, other);
invoices have their fields extracted into the AP system; when a clerk flags
a problem, the bot drafts a reply to the vendor for the clerk to edit.

## Code

- `invoicebot/classify.py`: labels an incoming email.
- `invoicebot/extract.py`: extracts vendor, GSTIN, invoice number, date,
  total and currency from invoice text.
- `invoicebot/reply.py`: drafts an email to a vendor about a flagged problem.
  `vendor_name` comes from the extracted invoice; `issue` is typed by the
  clerk.
- `invoicebot/llm.py`: the model client interface. Production wires the
  vendor SDK behind `LLMClient`; tests use fakes. `RecordedLLM` replays the
  extractor's production responses for the ten finance-labelled invoices,
  captured on 2026-08-20 (`tests/recorded/extract.jsonl`). It refuses to
  replay a request whose system prompt differs from the one recorded.

Model in production: `claude-sonnet-5` for extraction and replies,
`claude-haiku-4-5` for classification. There is no API key on laptops or
in CI.

## Test data

`tests/fixtures/invoices.jsonl`: ten real-shaped invoices (anonymised) with
the fields finance-ops confirmed by hand. Three are from small vendors that
are not GST-registered and print no GSTIN.

## Commands

    make test
