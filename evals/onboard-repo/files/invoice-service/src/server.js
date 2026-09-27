import { createServer } from "node:http";
import { invoiceTotals } from "./invoice.js";

const port = Number(process.env.PORT ?? 8080);

createServer((req, res) => {
  if (req.method === "POST" && req.url === "/totals") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const { lines, rateBps } = JSON.parse(body);
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify(invoiceTotals(lines, rateBps)));
      } catch (e) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: String(e.message) }));
      }
    });
    return;
  }
  res.writeHead(404).end();
}).listen(port);
