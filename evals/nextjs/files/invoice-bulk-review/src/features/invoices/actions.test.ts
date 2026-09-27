import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/cache", () => ({ updateTag: vi.fn(), revalidateTag: vi.fn() }));
vi.mock("@/lib/session", () => ({ requireSession: vi.fn() }));
vi.mock("@/features/invoices/api", () => ({
  invoicesTag: (orgId: string) => `invoices:${orgId}`,
  voidInvoiceById: vi.fn(),
}));

import { updateTag } from "next/cache";
import { voidInvoiceById } from "@/features/invoices/api";
import { requireSession } from "@/lib/session";
import { voidInvoice } from "./actions";

const form = (id: string) => {
  const f = new FormData();
  f.set("id", id);
  return f;
};

describe("voidInvoice", () => {
  beforeEach(() => {
    vi.mocked(requireSession).mockResolvedValue({ userId: "u_1", orgId: "org_a", role: "admin" });
  });

  it("voids in the session's organisation and expires its list", async () => {
    const state = await voidInvoice({ status: "idle" }, form("inv_abcd1234"));
    expect(state.status).toBe("ok");
    expect(voidInvoiceById).toHaveBeenCalledWith("org_a", "inv_abcd1234");
    expect(updateTag).toHaveBeenCalledWith("invoices:org_a");
  });

  it("rejects a malformed id", async () => {
    const state = await voidInvoice({ status: "idle" }, form("../../x"));
    expect(state.status).toBe("error");
    expect(voidInvoiceById).not.toHaveBeenCalled();
  });
});
