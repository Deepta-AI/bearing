"""US-01-004 and US-01-005: the landlord assigns a vendor, who gets an SMS."""

from . import notify


class AssignError(ValueError):
    pass


def assign_vendor(store, request_id, vendor_id, sms=None):
    r = store.requests.get(request_id)
    v = store.vendors.get(vendor_id)
    if r is None or v is None:
        raise AssignError("unknown request or vendor")
    if r.status != "open":
        raise AssignError(f"request {request_id} is {r.status}")
    r.vendor_id = vendor_id
    r.status = "assigned"
    r.history.append("assigned")
    notify.send_sms(v.phone, f"New job #{r.id}: {r.description[:80]}", transport=sms)
    return r
