import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

export const API = "http://api.test";

export const asha = {
  id: "c_1",
  name: "Asha Rao",
  email: "asha@example.com",
  phone: "+91 98450 12345",
  createdAt: "2025-11-02T09:00:00Z",
  linkedAccounts: [{ id: "c_2", name: "Ravi Rao" }],
};

export const handlers = [
  http.get(`${API}/api/customers`, () => HttpResponse.json([asha])),
  http.get(`${API}/api/customers/:id`, () => HttpResponse.json(asha)),
];

export const server = setupServer(...handlers);
