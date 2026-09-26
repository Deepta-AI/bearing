# mcplite

A small MCP runtime for repositories that cannot take the `mcp` package.
Newline-delimited JSON-RPC 2.0 over stdio, protocol version 2025-06-18.
Implements `initialize`, `notifications/initialized`, `ping`, `tools/list`
and `tools/call`. No resources, prompts or HTTP transport yet.

    from mcplite.server import Server, ToolError
    server = Server("example")

    @server.tool("echo_text", description="...", input_schema={...},
                 annotations={...}, title="Echo text")
    def echo_text(text: str) -> dict:
        return {"text": text}

    if __name__ == "__main__":
        server.run_stdio()

`mcplite.client.StdioClient` starts a server as a subprocess and speaks the
protocol, for tests (see `tests/test_mcplite.py`). The server passes
`arguments` to the handler as keyword arguments as they arrive; it does not
validate them against the schema. Stdout carries protocol frames only.

Copied from the platform repository at tag mcplite-v0.3.1. Local changes
are allowed; note them here.
