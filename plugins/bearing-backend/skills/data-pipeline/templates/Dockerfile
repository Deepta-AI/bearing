# The dbt runner image: what the orchestrator executes for run, test and
# backfill. Airflow itself is deployed separately (managed or its own chart);
# this image is the task, not the scheduler.
FROM python:3.12-slim-bookworm AS build
COPY --from=ghcr.io/astral-sh/uv:0.11.30 /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
WORKDIR /app
# uv.lock is committed (make setup writes it); the glob keeps a first build
# working before it exists, at the cost of an unpinned resolution.
COPY pyproject.toml uv.lock* ./
RUN if [ -f uv.lock ]; then uv sync --locked --no-dev --no-install-project; \
    else echo "lockfile: no uv.lock committed, resolving unpinned (run uv lock and commit uv.lock)"; uv sync --no-dev --no-install-project; fi

FROM python:3.12-slim-bookworm
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app --no-create-home app
WORKDIR /app
COPY --from=build --chown=app:app /app/.venv /app/.venv
COPY --chown=app:app dbt ./dbt
# The profile reads everything from DBT_* variables; it holds no credential.
COPY --chown=app:app profiles.yml.example ./profiles.yml
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1 DBT_PROFILES_DIR=/app DBT_PROJECT_DIR=/app/dbt DBT_SEND_ANONYMOUS_USAGE_STATS=false
USER app
# DBT_PROJECT_DIR and DBT_PROFILES_DIR above point dbt at the project and profile.
ENTRYPOINT ["dbt", "--no-use-colors"]
CMD ["run"]
