"""US-01-001 and US-01-002: tenants file requests and see their status."""


class InvalidRequest(ValueError):
    pass


def file_request(store, flat_id, tenant_phone, description):
    description = (description or "").strip()
    if len(description) < 10:
        raise InvalidRequest("Describe the problem in at least 10 characters")
    return store.add_request(flat_id, tenant_phone, description)


def status_for_tenant(store, request_id, tenant_phone):
    r = store.requests.get(request_id)
    if r is None or r.tenant_phone != tenant_phone:
        return None
    return {"id": r.id, "status": r.status, "history": list(r.history)}
