.PHONY: check test

export PYTHONDONTWRITEBYTECODE = 1

check: test

test:
	pytest -q -p no:cacheprovider tests
