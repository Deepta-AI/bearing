import { describe, expect, it } from "vitest";

import { ConfigError, loadConfig } from "./config.js";

describe("loadConfig", () => {
  it("applies defaults to an empty environment", () => {
    const config = loadConfig({});

    expect(config.NODE_ENV).toBe("development");
    expect(config.PORT).toBe(8080);
    expect(config.LOG_LEVEL).toBe("info");
    expect(config.LOG_PRETTY).toBe(false);
    expect(config.DATABASE_URL).toBeUndefined();
    expect(config.OTEL_EXPORTER_OTLP_ENDPOINT).toBeUndefined();
  });

  it("reads and coerces values from the environment", () => {
    const config = loadConfig({
      PORT: "9000",
      LOG_LEVEL: "debug",
      LOG_PRETTY: "true",
      DATABASE_URL: "postgres://u:p@localhost:5432/db",
    });

    expect(config.PORT).toBe(9000);
    expect(config.LOG_LEVEL).toBe("debug");
    expect(config.LOG_PRETTY).toBe(true);
    expect(config.DATABASE_URL).toBe("postgres://u:p@localhost:5432/db");
  });

  it("treats an empty string as unset", () => {
    const config = loadConfig({ OTEL_EXPORTER_OTLP_ENDPOINT: "", DATABASE_URL: "" });

    expect(config.OTEL_EXPORTER_OTLP_ENDPOINT).toBeUndefined();
    expect(config.DATABASE_URL).toBeUndefined();
  });

  it.each([
    ["PORT", "eighty"],
    ["LOG_LEVEL", "loud"],
    ["NODE_ENV", "staging"],
    ["DATABASE_URL", "mysql://localhost/db"],
  ])("rejects an invalid %s and names it", (name, value) => {
    expect(() => loadConfig({ [name]: value })).toThrow(ConfigError);
    expect(() => loadConfig({ [name]: value })).toThrow(name);
  });

  it("names every invalid variable at once", () => {
    expect(() => loadConfig({ PORT: "x", LOG_LEVEL: "y" })).toThrow(/PORT[\s\S]*LOG_LEVEL/);
  });
});
