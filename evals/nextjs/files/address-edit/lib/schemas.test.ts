import { describe, expect, it } from "vitest";
import { AddressSchema, UpdateNameSchema } from "./schemas";

describe("schemas", () => {
  it("reads an old LK address from the API", () => {
    const a = AddressSchema.parse({
      id: "a_9", customerId: "c_1", label: "Colombo", line1: "12 Galle Road", line2: null,
      city: "Colombo", state: "Western", pin: "00300", country: "LK", phone: "+94 77 123 4567",
    });
    expect(a.country).toBe("LK");
  });

  it("trims a name", () => {
    expect(UpdateNameSchema.parse({ name: "  Asha " }).name).toBe("Asha");
  });
});
