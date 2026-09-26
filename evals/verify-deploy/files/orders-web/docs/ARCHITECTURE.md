# Architecture

One Next.js web app talks to one Go API over HTTP. Postgres holds the
orders. Both run as containers on the team's Kubernetes cluster, one
namespace per environment (qa, prod).
