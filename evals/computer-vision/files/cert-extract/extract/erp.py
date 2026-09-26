"""Goods-receipt API of the ERP."""

import json
import os
import urllib.request


def post_certificate(doc_id, fields):
    """Write the certificate fields onto the goods receipt. fields: {name: value}."""
    body = json.dumps({"doc_id": doc_id, "fields": fields}).encode()
    req = urllib.request.Request(
        os.environ["ERP_URL"] + "/goods-receipts/certificates",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status


def queue_for_manual_entry(doc_id, fields, reason):
    """Put the certificate on the stores team's manual entry list."""
    body = json.dumps({"doc_id": doc_id, "fields": fields, "reason": reason}).encode()
    req = urllib.request.Request(
        os.environ["ERP_URL"] + "/manual-entry",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status
