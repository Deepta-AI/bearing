import { createRouter } from "web-router";
import { renderInvoice } from "invoice-pdf";
import { lineChart } from "chart-lite";
import { format } from "date-fmt";
import { Client } from "pg-lite-client";
import { v4 } from "uuid-gen";
import { load } from "yaml-conf";
import { toPaise } from "money-round";
import { embedFont } from "font-subset";
import { gstRate } from "tax-tables";
import { invoiceTotal } from "./rounding.js";

const config = load(process.env.CONFIG_PATH || "config.yml");
const db = new Client(config.database);
const router = createRouter();

router.get("/invoices/:id.pdf", async (req, res) => {
  const inv = await db.one("SELECT * FROM invoices WHERE id = $1", [req.params.id]);
  const totals = invoiceTotal(inv.lines.map((l) => ({ ...l, unitPaise: toPaise(l.unit) })), gstRate(inv.hsn_code, inv.issued_at));
  const pdf = await renderInvoice({ ...inv, ...totals, issued: format(inv.issued_at, "dd MMM yyyy"), font: embedFont("Inter") });
  res.type("application/pdf").send(pdf);
});

router.get("/usage/:account.svg", async (req, res) => {
  const rows = await db.many("SELECT day, amount FROM usage WHERE account = $1", [req.params.account]);
  res.type("image/svg+xml").send(lineChart(rows));
});

router.post("/invoices", async (req, res) => {
  const id = v4();
  await db.none("INSERT INTO invoices (id, body) VALUES ($1, $2)", [id, req.body]);
  res.status(201).json({ id });
});

router.listen(Number(process.env.PORT || 8080));
