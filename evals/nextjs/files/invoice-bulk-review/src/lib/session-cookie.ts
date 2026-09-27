import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { env } from "@/env.server";
import type { Session } from "@/lib/session";

// The session cookie is an HS256 compact JWS signed with SESSION_SECRET.
export async function verifySessionCookie(raw: string): Promise<Session | null> {
  const [h, p, s] = raw.split(".");
  if (!h || !p || !s) return null;
  const mac = createHmac("sha256", env.SESSION_SECRET).update(`${h}.${p}`).digest();
  const sig = Buffer.from(s, "base64url");
  if (sig.length !== mac.length || !timingSafeEqual(sig, mac)) return null;
  const payload = JSON.parse(Buffer.from(p, "base64url").toString("utf8"));
  if (typeof payload.exp === "number" && payload.exp * 1000 < Date.now()) return null;
  return { userId: payload.sub, orgId: payload.org, role: payload.role };
}
