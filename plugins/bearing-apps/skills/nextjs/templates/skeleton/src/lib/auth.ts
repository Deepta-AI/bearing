import "server-only";

import { cookies } from "next/headers";

/** Session is what an action or a page knows about the caller. */
export interface Session {
  userId: string | null;
}

/**
 * getSession reads the session cookie. Replace the body with the real
 * identity provider; keep the shape. Server actions call requireSession
 * before doing anything, because an action is a public HTTP endpoint
 * whatever component renders the form.
 */
export async function getSession(): Promise<Session> {
  const store = await cookies();
  const value = store.get("session")?.value;
  return { userId: value && value.length > 0 ? value : null };
}

/** UnauthorisedError is thrown by requireSession; error.tsx renders it. */
export class UnauthorisedError extends Error {
  constructor() {
    super("sign in to continue");
    this.name = "UnauthorisedError";
  }
}

/**
 * requireSession returns the session or throws. The template allows an
 * anonymous caller so the scaffold works before auth exists; tighten it to
 * `if (!session.userId) throw new UnauthorisedError()` with the first
 * protected action.
 */
export async function requireSession(): Promise<Session> {
  return getSession();
}
