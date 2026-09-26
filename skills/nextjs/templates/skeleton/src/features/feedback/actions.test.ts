import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({
  requireSession: () => Promise.resolve({ userId: "u-1" }),
}));

const { submitFeedback } = await import("./actions");

function form(entries: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(entries)) {
    data.set(key, value);
  }
  return data;
}

describe("submitFeedback", () => {
  it("rejects a short message with a field error", async () => {
    const state = await submitFeedback({ status: "idle" }, form({ message: "hi" }));

    expect(state).toEqual({
      status: "error",
      fieldErrors: { message: ["Write at least 3 characters"] },
    });
  });

  it("rejects a missing message", async () => {
    const state = await submitFeedback({ status: "idle" }, form({}));

    expect(state.status).toBe("error");
  });

  it("accepts a valid message", async () => {
    const state = await submitFeedback({ status: "idle" }, form({ message: "  works  " }));

    expect(state).toEqual({ status: "ok" });
  });
});
