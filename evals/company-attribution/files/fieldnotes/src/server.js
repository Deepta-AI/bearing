import http from "node:http";
import { createUser } from "./users.js";

const users = new Map();

export function handler(req, res) {
  if (req.method === "POST" && req.url === "/users") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const user = createUser(users, JSON.parse(body || "{}"));
        res.writeHead(201, { "content-type": "application/json" });
        res.end(JSON.stringify(user));
      } catch (e) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }
  res.writeHead(404);
  res.end();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  http.createServer(handler).listen(process.env.PORT || 8080);
}
