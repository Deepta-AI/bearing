KIT := Packages/CornerKit

.PHONY: help generate dev check fix test

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

generate: ## project.yml -> Corner.xcodeproj
	xcodegen generate

dev: generate ## Generate and open in Xcode
	open Corner.xcodeproj

check: ## Format lint, SwiftLint strict, package tests
	swiftformat --lint .
	swiftlint --strict
	swift test --package-path $(KIT)

fix: ## Apply formatting and lint fixes
	swiftformat .
	swiftlint --fix

test: ## Package tests
	swift test --package-path $(KIT)
