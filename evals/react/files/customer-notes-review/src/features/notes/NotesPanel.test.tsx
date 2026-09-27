import { screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { renderAt } from "@/test/render";
import { NotesPanel } from "./NotesPanel";

describe("NotesPanel", () => {
  it("shows the customer's notes", async () => {
    renderAt("/customers/c_1", "/customers/:customerId", <NotesPanel customerId="c_1" />);
    expect(await screen.findByText(/late refund/)).toBeInTheDocument();
  });
});
