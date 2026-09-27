PYTHON ?= python3.12

.PHONY: check run

check:
	$(PYTHON) -m unittest discover -s tests -q

run:
	$(PYTHON) -m export.worker
