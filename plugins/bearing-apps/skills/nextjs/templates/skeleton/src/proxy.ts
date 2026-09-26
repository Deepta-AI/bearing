import { NextResponse, type NextRequest } from "next/server";

// Proxy (the Next 16 name for middleware) runs on the Node.js runtime before
// every matched request. It is for headers, redirects and rewrites only: no
// database, no heavy work, no authorisation decision that a page or action
// does not repeat.
export function proxy(request: NextRequest) {
  const requestId = request.headers.get("x-request-id") ?? crypto.randomUUID();
  const headers = new Headers(request.headers);
  headers.set("x-request-id", requestId);
  const response = NextResponse.next({ request: { headers } });
  response.headers.set("x-request-id", requestId);
  return response;
}

export const config = {
  // Everything except static assets and the image optimiser.
  matcher: ["/((?!_next/static|_next/image|favicon.svg).*)"],
};
