# invoice-intake

Accounts payable intake. A customer's finance user uploads a vendor
invoice (PDF); the platform's PDF service turns it into text, and this
service asks the model to extract the invoice fields. The model can look up
the vendor, email the vendor when something is missing, or flag the invoice
for a person. Extracted invoices go to the payables queue, where they are
paid on the due date.

Python 3.12+, standard library only. The model is reached through
`intake/llm.py` (`ModelClient`); the production client is in the platform
image. Tests use `tests/fakes.py` and never call a provider.

- `intake/pipeline.py`: the intake flow and the tools
- `intake/vendors.py`: the vendor master (payee bank details live here)
- `intake/mailer.py`, `intake/store.py`: outbound email, the payables queue
- `samples/`: extracted text of uploaded invoices (synthetic)
- `docs/security/review-2026-09.md`: the security review findings

    make check
