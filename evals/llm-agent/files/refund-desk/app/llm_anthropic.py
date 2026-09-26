"""Production ModelClient. The anthropic package is installed in the platform
image only; importing this module anywhere else fails, which is intended."""

from app.llm import ModelResponse, Usage


class AnthropicModel:
    def __init__(self, timeout_s: float = 60.0):
        import anthropic  # noqa: PLC0415  (platform image only)

        self._client = anthropic.Anthropic(timeout=timeout_s)

    def create(self, *, model, system, messages, tools, max_tokens):
        r = self._client.messages.create(
            model=model, system=system, messages=messages, tools=tools, max_tokens=max_tokens
        )
        return ModelResponse(
            content=[b.model_dump() for b in r.content],
            stop_reason=r.stop_reason,
            usage=Usage(
                r.usage.input_tokens,
                r.usage.output_tokens,
                r.usage.cache_read_input_tokens or 0,
            ),
            request_id=getattr(r, "_request_id", "") or "",
            model=model,
        )
