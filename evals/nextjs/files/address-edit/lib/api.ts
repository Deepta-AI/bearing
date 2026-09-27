import "server-only";
import { z } from "zod";
import { env } from "@/lib/env.server";
import { AddressSchema, CustomerSchema, type Address, type Customer } from "@/lib/schemas";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly fieldErrors: Record<string, string> = {},
  ) {
    super(`commerce API answered ${status}`);
  }
}

async function call(path: string, init: RequestInit & { next?: NextFetchRequestConfig } = {}) {
  const res = await fetch(`${env.API_URL}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${env.API_TOKEN}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
  if (!res.ok) {
    const body = res.status === 422 ? await res.json().catch(() => ({})) : {};
    throw new ApiError(res.status, body.errors ?? {});
  }
  return res.json();
}

export const customerTag = (customerId: string) => `customer:${customerId}`;
export const addressesTag = (customerId: string) => `customer:${customerId}:addresses`;

export async function getCustomer(customerId: string): Promise<Customer> {
  const data = await call(`/customers/${customerId}`, {
    next: { tags: [customerTag(customerId)], revalidate: 300 },
  });
  return CustomerSchema.parse(data);
}

export async function updateCustomerName(customerId: string, name: string): Promise<Customer> {
  const data = await call(`/customers/${customerId}`, {
    method: "PATCH",
    body: JSON.stringify({ name }),
  });
  return CustomerSchema.parse(data);
}

export async function listAddresses(customerId: string): Promise<Address[]> {
  const data = await call(`/customers/${customerId}/addresses`, {
    next: { tags: [addressesTag(customerId)], revalidate: 3600 },
  });
  return z.object({ items: z.array(AddressSchema) }).parse(data).items;
}
