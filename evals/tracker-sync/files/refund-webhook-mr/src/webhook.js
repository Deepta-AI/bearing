// Refund webhook from the payment provider (SHOP-142). The provider signs
// "<timestamp>.<raw body>" with HMAC-SHA256 and sends
// "t=<unix seconds>,v1=<hex>" in the Provider-Signature header.
import { createHmac, timingSafeEqual } from "node:crypto";
import { recordRefund } from "./refunds.js";
import { log } from "./logger.js";

export function verifySignature(header, rawBody, secret) {
  const parts = Object.fromEntries(
    String(header || "").split(",").map((kv) => kv.split("=", 2)),
  );
  if (!parts.t || !parts.v1) return false;
  const want = createHmac("sha256", secret).update(`${parts.t}.${rawBody}`).digest("hex");
  const a = Buffer.from(want, "hex");
  const b = Buffer.from(parts.v1, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

export function handleRefundWebhook({ header, rawBody }, secret) {
  if (!verifySignature(header, rawBody, secret)) {
    log("warn", "refund webhook rejected: bad signature");
    return { status: 401 };
  }
  const event = JSON.parse(rawBody);
  if (event.type !== "refund.updated") return { status: 204 };
  recordRefund(event.data);
  return { status: 200 };
}
