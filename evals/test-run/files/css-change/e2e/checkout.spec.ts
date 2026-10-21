import { expect, test } from "@playwright/test";

test("TC-0310 checkout shows the order total", async ({ page }) => {
  await page.goto("/checkout");
  await expect(page.getByRole("heading", { name: "Order total" })).toBeVisible();
});
