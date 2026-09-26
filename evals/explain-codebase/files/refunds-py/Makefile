.PHONY: run check

run:
	PYTHONPATH=src python3 -m refunds.worker

check:
	PYTHONPATH=src python3 -m unittest discover -s tests -p '*_test.py' -v
