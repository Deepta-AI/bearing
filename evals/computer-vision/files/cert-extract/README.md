# cert-extract

Reads mill test certificates that arrive with steel deliveries (scanned PDFs
from three suppliers) and fills the goods-receipt record in the ERP:
certificate number, heat number, issue date, grade and yield strength (MPa).
Today the stores team types these in by hand.

Extraction is done by a vision language model behind one function,
`extract.vlm.extract_fields(path)`, which returns every field with a value and
the model's own confidence between 0 and 1.

## Labelled set

`data/labelled/labels.jsonl` has the correct values for 40 certificates,
checked by the stores team. `data/labelled/predictions.jsonl` has what the
model returned for the same 40 scans (run on 2 September with model
`vlm-extract-2026-08`). The scans themselves are on the shared drive, not in
this repository.

Suppliers: north-rolling (18 certificates), deccan-steel (14, prints dates as
DD/MM/YYYY), kaveri-alloys (8, heat numbers like K3O517 with a letter O).

Volume: about 60 certificates a working day. Last quarter's deliveries by
supplier were north-rolling 20%, deccan-steel 55% and kaveri-alloys 25% of
certificates. The 40 were picked to cover all three suppliers, not in
proportion to deliveries.

## Tests

    make test
