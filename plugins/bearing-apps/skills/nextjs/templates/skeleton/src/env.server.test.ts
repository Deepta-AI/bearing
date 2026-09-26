import { describe, expect, it } from "vitest";

import { parseServerEnv } from "./env.server";

describe("parseServerEnv", () => {
  it("applies defaults and strips a trailing slash", () => {
    const env = parseServerEnv({ API_URL: "http://api.internal/" });

    expect(env.API_URL).toBe("http://api.internal");
    expect(env.NODE_ENV).toBe("development");
    expect(env.SERVICE_VERSION).toBe("dev");
  });

  it("treats an empty string as unset", () => {
    expect(parseServerEnv({ API_URL: "" }).API_URL).toBe("http://localhost:8080");
  });

  it("names an invalid variable", () => {
    expect(() => parseServerEnv({ API_URL: "not a url" })).toThrow("API_URL");
    expect(() => parseServerEnv({ NODE_ENV: "staging" })).toThrow("NODE_ENV");
  });
});
