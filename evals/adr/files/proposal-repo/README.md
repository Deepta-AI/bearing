# export-service

Builds customer CSV exports in the background. A Python worker reads jobs
from SQS; job state lives in Postgres.
