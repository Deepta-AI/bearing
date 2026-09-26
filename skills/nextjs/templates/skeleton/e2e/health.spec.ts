import { expect, test } from "@playwright/test";

// Runs against a production build. API_URL points at this app's own
// /api route handlers (playwright.config.ts), so the server component's
// fetch has something real to talk to; page.route cannot reach it.
test.describe("health", () => {
  test("renders the health card from the server", async ({ page }) => {
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "API health" })).toBeVisible();
    await expect(page.getByRole("status").first()).toContainText("ok");
  });

  test("serves the probes", async ({ request }) => {
    const health = await request.get("/api/healthz");
    expect(health.ok()).toBe(true);
    expect(await health.json()).toMatchObject({ status: "ok" });

    const ready = await request.get("/api/readyz");
    expect(ready.ok()).toBe(true);
    expect(await ready.json()).toEqual({ status: "ok", checks: { api: "ok" } });
  });

  test("validates the feedback form through the server action", async ({ page }) => {
    await page.goto("/");

    await page.getByRole("button", { name: "Send" }).click();
    await expect(page.getByText("Write at least 3 characters")).toBeVisible();

    await page.getByRole("textbox", { name: "Message" }).fill("Works end to end");
    await page.getByRole("button", { name: "Send" }).click();
    await expect(page.getByText("Thanks, received.")).toBeVisible();
  });

  test("shows the not-found page for an unknown path", async ({ page }) => {
    const response = await page.goto("/nowhere");

    expect(response?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "Page not found" })).toBeVisible();
    await page.getByRole("link", { name: "Back to the start" }).click();
    await expect(page).toHaveURL(/\/$/);
  });
});
