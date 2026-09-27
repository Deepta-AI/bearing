import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { verifySessionCookie } from "@/lib/session-cookie";

export type Session = { userId: string; orgId: string; role: "admin" | "member" };

export async function requireSession(): Promise<Session> {
  const raw = (await cookies()).get("session")?.value;
  const session = raw ? await verifySessionCookie(raw) : null;
  if (!session) redirect("/login");
  return session;
}
