import { beforeEach, describe, expect, it, vi } from "vitest";

const cookieStore = new Map<string, string>();

vi.mock("next/headers", () => ({
  cookies: () =>
    Promise.resolve({
      get: (name: string) => {
        const value = cookieStore.get(name);
        return value === undefined ? undefined : { name, value };
      },
    }),
}));

const { getSession, requireSession, UnauthorisedError } = await import("./auth");

describe("getSession", () => {
  beforeEach(() => {
    cookieStore.clear();
  });

  it("is anonymous without a cookie", async () => {
    await expect(getSession()).resolves.toEqual({ userId: null });
  });

  it("reads the user from the cookie", async () => {
    cookieStore.set("session", "u-42");

    await expect(requireSession()).resolves.toEqual({ userId: "u-42" });
  });

  it("names the unauthorised error", () => {
    expect(new UnauthorisedError().name).toBe("UnauthorisedError");
  });
});
