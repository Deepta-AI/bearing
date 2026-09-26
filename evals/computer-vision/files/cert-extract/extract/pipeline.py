"""Certificate in, ERP record out."""

from extract import erp, vlm


def process(doc_id, path):
    fields = vlm.extract_fields(path)
    # TODO: decide what goes straight to the ERP and what goes to manual entry
    raise NotImplementedError
