# crm-notes-mcp

An MCP server over our CRM so the sales team can look up accounts and
keep call notes from Claude Code. Written in a hurry for the pilot with
two account managers; the whole sales team (about 40 people) gets it next.

Python 3.12+, standard library only (no third-party packages allowed on
sales laptops). The server speaks newline-delimited JSON-RPC over stdio
(MCP protocol version 2025-06-18) and is registered in `.mcp.json`.

- `mcp_server/server.py`: the server and its tools
- `crm/client.py`: CRM access; with `CRM_BASE_URL` empty it reads
  `data/crm.json` (synthetic sample data) instead of the CRM API
- `reports/`: report scripts the `run_report` tool runs

    make check

TODO: tests for the server.
