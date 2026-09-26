// Page object for Playwright. One class per page or dialog, locators by role
// and accessible name, actions named after what the user does. Tests never
// hold a locator; they call these methods and assert on what they return.
// Copy to e2e/pages/<Name>Page.ts and replace the health example.
import { expect, type Locator, type Page } from "@playwright/test";

export class HealthPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly status: Locator;
  readonly retry: Locator;

  constructor(page: Page) {
    this.page = page;
    // Role and accessible name first. A test id is the fallback when the
    // element has no accessible name; a CSS path is never acceptable.
    this.heading = page.getByRole("heading", { name: "API health" });
    this.status = page.getByRole("status");
    this.retry = page.getByRole("button", { name: "Retry" });
  }

  async goto(): Promise<void> {
    await this.page.goto("/");
    await expect(this.heading).toBeVisible();
  }

  async retryWithKeyboard(): Promise<void> {
    await this.retry.focus();
    await this.page.keyboard.press("Enter");
  }

  async expectStatus(text: string): Promise<void> {
    // The framework waits; no sleep, no polling loop in the test.
    await expect(this.status).toContainText(text);
  }
}

// Fixture: expose the page object so a spec reads
//   test("TC-0007 recovers through a keyboard-reachable retry", async ({ health }) => { ... })
// Put this in e2e/fixtures/index.ts and import `test` from there.
//
// import { test as base } from "@playwright/test";
// export const test = base.extend<{ health: HealthPage }>({
//   health: async ({ page }, use) => { await use(new HealthPage(page)); },
// });
// export { expect } from "@playwright/test";
