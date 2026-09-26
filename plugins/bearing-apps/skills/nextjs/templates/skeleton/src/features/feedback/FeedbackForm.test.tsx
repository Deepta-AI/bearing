import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { FeedbackForm } from "./components/FeedbackForm";
import { type FeedbackState } from "./schema";

describe("FeedbackForm", () => {
  it("submits the message to the action and announces success", async () => {
    const action = vi.fn((_state: FeedbackState, data: FormData): Promise<FeedbackState> => {
      expect(data.get("message")).toBe("Looks good");
      return Promise.resolve({ status: "ok" });
    });
    const user = userEvent.setup();

    render(<FeedbackForm action={action} />);

    await user.type(screen.getByRole("textbox", { name: "Message" }), "Looks good");
    await user.click(screen.getByRole("button", { name: "Send" }));

    expect(await screen.findByText("Thanks, received.")).toBeInTheDocument();
    expect(action).toHaveBeenCalledTimes(1);
  });

  it("shows the field error the action returns and links it to the field", async () => {
    const action = vi.fn((): Promise<FeedbackState> =>
      Promise.resolve({
        status: "error",
        fieldErrors: { message: ["Write at least 3 characters"] },
      }),
    );
    const user = userEvent.setup();

    render(<FeedbackForm action={action} />);

    await user.click(screen.getByRole("button", { name: "Send" }));

    const field = screen.getByRole("textbox", { name: "Message" });
    expect(await screen.findByText("Write at least 3 characters")).toBeInTheDocument();
    expect(field).toHaveAttribute("aria-invalid", "true");
    expect(field).toHaveAccessibleDescription("Write at least 3 characters");
  });
});
