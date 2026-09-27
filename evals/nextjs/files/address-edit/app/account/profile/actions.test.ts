import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/cache", () => ({ revalidateTag: vi.fn() }));
vi.mock("@/lib/session", () => ({ requireSession: vi.fn() }));
vi.mock("@/lib/api", async () => {
  const actual = await vi.importActual<typeof import("@/lib/api")>("@/lib/api");
  return { ...actual, updateCustomerName: vi.fn() };
});

import { revalidateTag } from "next/cache";
import { updateCustomerName } from "@/lib/api";
import { requireSession } from "@/lib/session";
import { updateName } from "./actions";

const form = (name: string) => {
  const f = new FormData();
  f.set("name", name);
  return f;
};

describe("updateName", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(requireSession).mockResolvedValue({ customerId: "c_1" });
    vi.mocked(updateCustomerName).mockResolvedValue({ id: "c_1", name: "Asha", email: "a@example.com" });
  });

  it("saves for the signed-in customer and revalidates their tag", async () => {
    const state = await updateName({ status: "idle" }, form("Asha"));
    expect(state.status).toBe("ok");
    expect(updateCustomerName).toHaveBeenCalledWith("c_1", "Asha");
    expect(revalidateTag).toHaveBeenCalledWith("customer:c_1");
  });

  it("rejects an empty name without calling the API", async () => {
    const state = await updateName({ status: "idle" }, form("  "));
    expect(state.status).toBe("error");
    expect(updateCustomerName).not.toHaveBeenCalled();
  });
});
