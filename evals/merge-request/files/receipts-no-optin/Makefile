.PHONY: check test

check: test
	@mkdir -p .bearing/state && touch .bearing/state/.check-passed
	@echo "check: passed"

test:
	python3 -m unittest discover -s tests -t . -q
