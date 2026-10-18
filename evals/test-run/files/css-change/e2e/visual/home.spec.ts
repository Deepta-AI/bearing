import { expect, test } from "@playwright/test";

test("TC-0320 home page matches the baseline", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveScreenshot("home.png");
});
