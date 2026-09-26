#!/bin/sh
# Copies the package to the stock host and restarts the service.
set -eu
echo "deploying stock-api $(python -c 'import tomllib;print(tomllib.load(open("pyproject.toml","rb"))["project"]["version"])')"
rsync -a --delete stock wsgi.py "deploy@${STOCK_HOST:?STOCK_HOST not set}:/srv/stock/app/"
ssh "deploy@${STOCK_HOST}" 'sudo systemctl restart stock-api'
