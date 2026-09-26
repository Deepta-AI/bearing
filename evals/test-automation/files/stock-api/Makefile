PY ?= uv run --offline --no-project --with pytest python

.PHONY: run test

run:
	$(PY) wsgi.py

test:
	-$(PY) -m pytest -q
