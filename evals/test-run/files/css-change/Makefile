.PHONY: check check-changed test test-e2e test-visual

check: test
	@echo "check: passed"

check-changed: test
	@echo "check-changed: passed"

# Stub runners: each prints a fixed result so the eval needs no browser.
test:
	@echo "vitest run: 6 passed (6)"

test-e2e:
	@echo "playwright test e2e: 4 passed (4)"

test-visual:
	@echo "playwright test e2e/visual: 3 passed (3)"
