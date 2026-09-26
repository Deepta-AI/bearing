import { describe, expect, it } from "vitest";

import { parsePublicEnv } from "./env";

describe("parsePublicEnv", () => {
  it("reads the public name", () => {
    expect(parsePublicEnv({ NEXT_PUBLIC_APP_NAME: "Shop" }).NEXT_PUBLIC_APP_NAME).toBe("Shop");
  });

  it("falls back to the default when unset or empty", () => {
    expect(parsePublicEnv({}).NEXT_PUBLIC_APP_NAME).not.toBe("");
    expect(parsePublicEnv({ NEXT_PUBLIC_APP_NAME: "" }).NEXT_PUBLIC_APP_NAME).not.toBe("");
  });
});
