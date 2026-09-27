import http from "node:http";
import { readFile } from "node:fs/promises";
import { signupPage } from "./views/signup.js";
import { welcomePage } from "./views/welcome.js";
import { reportsPage } from "./views/reports.js";
import { validateSignup } from "./validate.js";

const TYPES = { ".css": "text/css", ".js": "text/javascript", ".svg": "image/svg+xml", ".png": "image/png" };

async function readForm(req) {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  return Object.fromEntries(new URLSearchParams(raw));
}

export function createServer() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    const html = (status, body) => {
      res.writeHead(status, { "content-type": "text/html; charset=utf-8" });
      res.end(body);
    };
    if (req.method === "GET" && url.pathname === "/signup") return html(200, signupPage());
    if (req.method === "POST" && url.pathname === "/signup") {
      const form = await readForm(req);
      const errors = validateSignup(form);
      if (Object.keys(errors).length) return html(422, signupPage({ values: form, errors }));
      return html(200, welcomePage(form.name));
    }
    if (req.method === "GET" && url.pathname === "/reports") {
      return html(200, reportsPage([{ week: "2026-W38", count: 41 }, { week: "2026-W39", count: 57 }]));
    }
    if (url.pathname.startsWith("/public/")) {
      const ext = url.pathname.slice(url.pathname.lastIndexOf("."));
      try {
        const data = await readFile(new URL(`..${url.pathname}`, import.meta.url));
        res.writeHead(200, { "content-type": TYPES[ext] || "application/octet-stream" });
        return res.end(data);
      } catch {
        return html(404, "Not found");
      }
    }
    html(404, "Not found");
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 3000);
  createServer().listen(port, () => console.log(`listening on http://localhost:${port}`));
}
