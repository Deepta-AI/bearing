import { expect, test } from "vitest";
import { filterByCategory } from "./filter";

test("returns every item when the list is empty", () => {
  expect(filterByCategory([], "tea")).toEqual([]);
});
