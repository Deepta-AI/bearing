.PHONY: check test test-e2e

check: test
	@echo "check: passed"

# Stub runners: each prints a fixed result so the eval needs no browser.
test:
	@echo "vitest run: 5 passed (5)"

test-e2e:
	@echo "playwright test e2e: 1 failed, 2 passed (3)"
	@echo "  1) e2e/filter.spec.ts:4:1 > TC-0040 filter narrows the list to the chosen category"
	@echo "     Error: expect(locator).toHaveCount(2) - Expected: 2, Received: 5"
	@echo "       at e2e/filter.spec.ts:7"
	@exit 1
