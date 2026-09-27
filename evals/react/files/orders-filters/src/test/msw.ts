import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

export const API = "http://api.test";

export const sampleOrder = {
  id: "ord_1042",
  number: "SO-1042",
  customerEmail: "asha@example.com",
  status: "paid",
  totalPaise: 249900,
  placedAt: "2026-09-20T10:15:00Z",
};

export const handlers = [
  http.get(`${API}/api/orders`, ({ request }) => {
    const url = new URL(request.url);
    return HttpResponse.json({
      items: [sampleOrder],
      page: Number(url.searchParams.get("page") ?? 1),
      pageSize: 25,
      total: 1,
    });
  }),
  http.get(`${API}/api/orders/:id`, () => HttpResponse.json({ ...sampleOrder, lines: [] })),
];

export const server = setupServer(...handlers);
