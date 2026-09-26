"""Anthropic provider. The SDK is imported lazily so tests never need it."""

from llm.routing import Route
from llm.types import LLMRequest, ProviderResult, ProviderUnavailable, Usage


class AnthropicProvider:
    def __init__(self, max_retries: int = 2):
        import anthropic

        self._anthropic = anthropic
        self.client = anthropic.Anthropic(max_retries=max_retries)

    def complete(self, model: str, req: LLMRequest, route: Route) -> ProviderResult:
        kwargs = dict(model=model, max_tokens=req.max_tokens or route.max_tokens, messages=req.messages, timeout=route.timeout_s)
        if req.system:
            kwargs["system"] = req.system
        try:
            msg = self.client.messages.create(**kwargs)
        except self._anthropic.RateLimitError:
            raise ProviderUnavailable("rate_limited")
        except self._anthropic.APIStatusError as e:
            if e.status_code >= 500:
                raise ProviderUnavailable(f"http_{e.status_code}")
            raise
        text = "".join(b.text for b in msg.content if getattr(b, "type", "") == "text")
        return ProviderResult(
            text=text,
            model=msg.model,
            stop_reason=msg.stop_reason,
            usage=Usage(msg.usage.input_tokens, msg.usage.output_tokens),
            request_id=getattr(msg, "_request_id", None),
        )
