import { expect, test } from "vitest";
import { rupees } from "./format";

test("TC-0301 formats paise as rupees", () => {
  expect(rupees(12050)).toBe("Rs 120.50");
});
