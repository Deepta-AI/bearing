import { expect, test } from "@playwright/test";

// Visual regression: one screenshot per screen state that a person signed off.
// Runs only in the "visual" project (one browser, one viewport) and only
// inside the Playwright image: `make test-visual`, `make test-visual-update`.
// The API is mocked with page.route, the clock is frozen and anything that
// changes on its own (a timestamp, an avatar, a chart drawn from live data) is
// masked, so a diff means the page changed, not the data.
// The name carries the TC id of the row whose oracle is `ui: matches baseline`.

test.beforeEach(async ({ page }) => {
  await page.clock.setFixedTime(new Date("2026-01-01T09:00:00Z"));
  await page.route("**/healthz", (route) =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ status: "ok", version: "visual" }) }),
  );
});

test("TC-0000 home page matches its baseline", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("status")).toContainText("ok");
  // Mask what changes on its own, by role or test id that the page really has:
  // mask: [page.getByTestId("last-synced")]
  await expect(page).toHaveScreenshot("home.png", { fullPage: true });
});

test("TC-0000 not-found page matches its baseline", async ({ page }) => {
  await page.goto("/nowhere");
  await expect(page.getByRole("heading", { name: "Page not found" })).toBeVisible();
  await expect(page).toHaveScreenshot("not-found.png");
});
