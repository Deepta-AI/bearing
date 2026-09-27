"""US-01-010 and US-01-008: the landlord closes a job; the tenant rates it."""


class CloseError(ValueError):
    pass


def close_job(store, request_id):
    r = store.requests.get(request_id)
    if r is None or r.status != "assigned":
        raise CloseError("only an assigned job can be closed")
    r.status = "closed"
    r.history.append("closed")
    # Payout (US-01-007) hooks in here once the PayGate client exists.
    return r


def rate_vendor(store, request_id, tenant_phone, stars):
    r = store.requests.get(request_id)
    if r is None or r.tenant_phone != tenant_phone:
        raise CloseError("unknown request")
    if r.status != "closed":
        raise CloseError("only a closed job can be rated")
    if r.rating is not None:
        raise CloseError("already rated")
    if stars not in range(1, 6):
        raise CloseError("rating is 1 to 5")
    r.rating = stars
    return r
