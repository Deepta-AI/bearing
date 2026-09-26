import http from "k6/http";
import { check } from "k6";

export const options = { vus: 20, duration: "2m" };

export default function () {
  const res = http.get(`${__ENV.BASE_URL}/invoices?status=overdue`);
  check(res, { "status is 200": (r) => r.status === 200 });
}
