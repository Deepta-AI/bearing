import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import ErrorPage from "./error";

describe("error boundary", () => {
  it("shows the message and offers a reset", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const reset = vi.fn();
    const user = userEvent.setup();

    render(<ErrorPage error={new Error("kaboom")} reset={reset} />);

    expect(screen.getByRole("alert")).toHaveTextContent("kaboom");
    await user.click(screen.getByRole("button", { name: "Try again" }));
    expect(reset).toHaveBeenCalledTimes(1);
  });

  it("shows the digest instead of the message when the server hid it", () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const error = Object.assign(new Error("internal"), { digest: "abc123" });

    render(<ErrorPage error={error} reset={() => undefined} />);

    expect(screen.getByRole("alert")).toHaveTextContent("Reference abc123");
    expect(screen.getByRole("alert")).not.toHaveTextContent("internal");
  });
});
