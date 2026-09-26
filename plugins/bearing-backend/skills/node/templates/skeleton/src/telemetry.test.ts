import { describe, expect, it } from "vitest";

import { startTelemetry } from "./telemetry.js";

describe("startTelemetry", () => {
  it("stays off without an endpoint", () => {
    expect(startTelemetry({ serviceName: "test", version: "0" })).toBeNull();
    expect(startTelemetry({ endpoint: "", serviceName: "test", version: "0" })).toBeNull();
    expect(startTelemetry({ endpoint: "   ", serviceName: "test", version: "0" })).toBeNull();
  });

  it("starts an SDK with an endpoint and shuts it down cleanly", async () => {
    const sdk = startTelemetry({
      endpoint: "http://localhost:4318/",
      serviceName: "test",
      version: "0",
    });

    expect(sdk).not.toBeNull();
    await expect(sdk!.shutdown()).resolves.toBeUndefined();
  });
});
