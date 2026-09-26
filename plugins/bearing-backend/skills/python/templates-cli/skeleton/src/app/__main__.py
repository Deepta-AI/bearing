"""`python -m app` runs the same entry point as the console script."""

from app.cli import main

raise SystemExit(main())
