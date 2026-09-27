.PHONY: check test coupon-report

check: test
	@echo "check: passed"

test:
	python3 -m unittest discover -s tests -t .

coupon-report:
	@PYTHONPATH=. python3 scripts/coupon_report.py
