import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { jsonResponse } from "@/test/render";

import { HealthCard } from "./components/HealthCard";

// A server component is an async function: await it, then render the tree.
describe("HealthCard", () => {
  it("shows the status and version from the API", async () => {
    const fetchMock = vi.fn(() =>
      Promise.resolve(jsonResponse({ status: "ok", version: "1.2.3" })),
    );
    vi.stubGlobal("fetch", fetchMock);

    render(await HealthCard());

    expect(screen.getByRole("heading", { name: "API health" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("ok");
    expect(screen.getByText("1.2.3")).toBeInTheDocument();
    const [url] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("http://api.test/healthz");
  });

  it("renders the error state instead of throwing", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.resolve(jsonResponse({ error: "down" }, 503))),
    );

    render(await HealthCard());

    expect(screen.getByRole("status")).toHaveTextContent("GET /healthz: 503");
  });

  it("treats a body that fails the schema as an error", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.resolve(jsonResponse({ status: 42 }))),
    );

    render(await HealthCard());

    expect(screen.getByRole("status")).toHaveTextContent(/failed validation/);
  });
});
