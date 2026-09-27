"""Provider event payloads. Unknown fields are ignored: the provider adds them freely."""

from pydantic import BaseModel, ConfigDict, Field


class EventData(BaseModel):
    model_config = ConfigDict(extra="ignore")

    invoice_id: str
    amount_minor: int = Field(gt=0)
    currency: str


class ProviderEvent(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    type: str
    created: str
    data: EventData


class WebhookAck(BaseModel):
    status: str
