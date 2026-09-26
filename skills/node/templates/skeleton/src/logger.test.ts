import { describe, expect, it } from "vitest";

import { createLogger, loggerOptions } from "./logger.js";

describe("loggerOptions", () => {
  it("uses JSON lines with redaction by default", () => {
    const options = loggerOptions({ LOG_LEVEL: "warn", LOG_PRETTY: false });

    expect(options.level).toBe("warn");
    expect(options.transport).toBeUndefined();
    expect(options.redact).toMatchObject({ censor: "[redacted]" });
  });

  it("adds the pretty transport when asked", () => {
    const options = loggerOptions({ LOG_LEVEL: "debug", LOG_PRETTY: true });

    expect(options.transport).toMatchObject({ target: "pino-pretty" });
  });
});

describe("createLogger", () => {
  it("returns a logger at the configured level", () => {
    const logger = createLogger({ LOG_LEVEL: "silent", LOG_PRETTY: false });

    expect(logger.level).toBe("silent");
    expect(typeof logger.info).toBe("function");
  });
});
