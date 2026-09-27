import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { env } from "@/lib/env.server";

export type Session = { customerId: string };

// The sid cookie is "<customerId>.<hmac>". Returns null when it is missing
// or does not verify.
export async function getSession(): Promise<Session | null> {
  const sid = (await cookies()).get("sid")?.value;
  if (!sid) return null;
  const [customerId, mac] = sid.split(".");
  if (!customerId || !mac) return null;
  const expected = createHmac("sha256", env.SESSION_SECRET).update(customerId).digest("hex");
  const a = Buffer.from(mac, "hex");
  const b = Buffer.from(expected, "hex");
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  return { customerId };
}

export async function requireSession(): Promise<Session> {
  const session = await getSession();
  if (!session) redirect("/login");
  return session;
}
