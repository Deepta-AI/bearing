"""The provider's single webhook endpoint (docs/provider-webhooks.md)."""

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from pydantic import ValidationError

from app.config import Settings, settings_dep
from app.db import Database, get_db
from app.errors import DomainError, ValidationFailed
from app.webhooks.schemas import ProviderEvent, WebhookAck
from app.webhooks.service import apply_payment
from app.webhooks.signing import verify_signature

log = logging.getLogger(__name__)
router = APIRouter(prefix="/webhooks", tags=["webhooks"])


class BadSignature(DomainError):
    status_code = 401
    code = "bad_signature"


@router.post("/payments", response_model=WebhookAck)
async def provider_webhook(
    request: Request,
    db: Annotated[Database, Depends(get_db)],
    settings: Annotated[Settings, Depends(settings_dep)],
) -> WebhookAck:
    raw = await request.body()
    secret = settings.webhook_secret.get_secret_value()
    if not verify_signature(raw, request.headers.get("X-Signature"), secret):
        raise BadSignature("signature does not match")
    try:
        event = ProviderEvent.model_validate_json(raw)
    except ValidationError as exc:
        raise ValidationFailed("event payload is invalid") from exc

    if event.type == "payment.succeeded":
        outcome = await apply_payment(db, event)
    else:
        outcome = "ignored"
    log.info("provider event %s type=%s outcome=%s", event.id, event.type, outcome)
    return WebhookAck(status=outcome)
