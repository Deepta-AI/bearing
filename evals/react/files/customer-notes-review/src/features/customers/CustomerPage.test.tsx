import { screen } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";
import { API, server } from "@/test/msw";
import { renderAt } from "@/test/render";
import { CustomerPage } from "./CustomerPage";

describe("CustomerPage", () => {
  it("shows the customer", async () => {
    renderAt("/customers/c_1", "/customers/:customerId", <CustomerPage />);
    expect(await screen.findByRole("heading", { name: "Asha Rao" })).toBeInTheDocument();
    expect(screen.getByText("asha@example.com")).toBeInTheDocument();
  });

  it("offers a retry when the API fails", async () => {
    server.use(http.get(`${API}/api/customers/:id`, () => HttpResponse.json({ error: { code: "boom", message: "x" } }, { status: 500 })));
    renderAt("/customers/c_1", "/customers/:customerId", <CustomerPage />);
    expect(await screen.findByRole("button", { name: "Retry" })).toBeInTheDocument();
  });
});
