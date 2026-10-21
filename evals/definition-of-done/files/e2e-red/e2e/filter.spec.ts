import { expect, test } from "@playwright/test";

// TC-0040: choosing a category narrows the list to that category.
test("TC-0040 filter narrows the list to the chosen category", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("combobox", { name: "Category" }).selectOption("tea");
  await expect(page.getByRole("listitem")).toHaveCount(2);
});
