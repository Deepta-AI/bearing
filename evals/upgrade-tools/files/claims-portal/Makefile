.PHONY: check test tooling bootstrap

check: tooling test

tooling:
	python3 scripts/check_tooling.py

test:
	PYTHONPATH=src python3 -m unittest discover -s tests -t . -v

bootstrap:
	bash scripts/bootstrap.sh
