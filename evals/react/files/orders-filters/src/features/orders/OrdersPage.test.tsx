import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";
import { API, sampleOrder, server } from "@/test/msw";
import { renderAt } from "@/test/render";
import { OrdersPage } from "./OrdersPage";

describe("OrdersPage", () => {
  it("lists orders from the API", async () => {
    renderAt("/orders", "/orders", <OrdersPage />);
    expect(await screen.findByRole("link", { name: "SO-1042" })).toBeInTheDocument();
    expect(screen.getByText("asha@example.com")).toBeInTheDocument();
  });

  it("asks for the next page", async () => {
    const pages: string[] = [];
    server.use(
      http.get(`${API}/api/orders`, ({ request }) => {
        const page = new URL(request.url).searchParams.get("page") ?? "1";
        pages.push(page);
        return HttpResponse.json({ items: [sampleOrder], page: Number(page), pageSize: 25, total: 60 });
      }),
    );
    renderAt("/orders", "/orders", <OrdersPage />);
    await userEvent.click(await screen.findByRole("button", { name: "Next" }));
    expect(await screen.findByText("Page 2 of 3")).toBeInTheDocument();
    expect(pages).toContain("2");
  });

  it("offers a retry when the API fails", async () => {
    server.use(http.get(`${API}/api/orders`, () => HttpResponse.json({ error: { code: "boom", message: "x" } }, { status: 500 })));
    renderAt("/orders", "/orders", <OrdersPage />);
    expect(await screen.findByRole("button", { name: "Retry" })).toBeInTheDocument();
  });
});
