import { NextResponse, type NextRequest } from "next/server";

// Sends signed-out visitors to /login before the account pages render.
// Checks only that a session cookie is present; it is not verified here.
export function middleware(request: NextRequest) {
  if (!request.cookies.has("sid")) {
    const url = new URL("/login", request.url);
    url.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = { matcher: ["/account/:path*"] };
