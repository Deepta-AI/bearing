"""A one-tool server used to test mcplite itself."""

from mcplite.server import Server, ToolError

server = Server("example")


@server.tool(
    "echo_text",
    title="Echo text",
    description="Returns the text it was given. Use it to check the connection.",
    input_schema={
        "type": "object",
        "properties": {
            "text": {"type": "string", "maxLength": 100, "description": "Text to echo"}
        },
        "required": ["text"],
        "additionalProperties": False,
    },
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": False,
    },
)
def echo_text(text: str) -> dict:
    if len(text) > 100:
        raise ToolError("invalid_input", "text is longer than 100 characters")
    return {"text": text}


if __name__ == "__main__":
    server.run_stdio()
