import { expect, test } from "@playwright/test";

test("TC-0038 home lists the catalogue", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("list", { name: "Products" })).toBeVisible();
});
