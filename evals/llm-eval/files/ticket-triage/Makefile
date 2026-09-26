PY ?= uv run --offline --no-project --with pytest

.PHONY: test lint
test:
	$(PY) pytest -q
lint:
	python3 -m py_compile triage/*.py scripts/*.py
