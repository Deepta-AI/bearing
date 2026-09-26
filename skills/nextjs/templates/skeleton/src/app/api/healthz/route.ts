import { connection } from "next/server";

import { serverEnv } from "@/env.server";

// Liveness for the container: the process serves requests. Under Cache
// Components a GET handler that reads nothing dynamic is prerendered at
// build, and a prerendered probe would lie; connection() makes it answer
// at request time.
export async function GET(): Promise<Response> {
  await connection();
  return Response.json({ status: "ok", version: serverEnv.SERVICE_VERSION });
}
