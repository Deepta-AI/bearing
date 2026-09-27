import http from "node:http";
import { validateEntry } from "./ledger.js";
import { connect } from "./db.js";

const port = Number(process.env.PORT || 8080);

export function handle(body) {
  const v = validateEntry(body);
  return v.ok ? { status: 201, body: { accepted: true } } : { status: 422, body: v };
}

if (process.argv[1] && process.argv[1].endsWith("server.js")) {
  const pool = await connect();
  http
    .createServer((req, res) => {
      let raw = "";
      req.on("data", (c) => (raw += c));
      req.on("end", async () => {
        const out = handle(JSON.parse(raw || "{}"));
        if (out.status === 201) await pool.query("select 1");
        res.writeHead(out.status, { "content-type": "application/json" });
        res.end(JSON.stringify(out.body));
      });
    })
    .listen(port);
}
