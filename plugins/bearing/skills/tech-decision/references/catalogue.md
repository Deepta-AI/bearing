# Decision catalogue

Ordered so earlier decisions constrain later ones. For each key: the
options worth presenting, the default recommendation, and the facts that
flip it. The default is where to start the conversation, not the answer.

## 1. cloud (provider)

Options: Google Cloud, AWS, Azure, Cloudflare (Workers, D1, R2), Hetzner
or another VPS host, on-premises.
Default: the provider the organisation already runs (from `.bearing/company.json`
or existing infra); with none, Google Cloud for a small team (managed
Postgres, GKE Autopilot, Cloud Run, simple IAM) or AWS when the client or
partner ecosystem is AWS.
Flips: data residency or a government client (the provider with the
in-country region and certifications); a mostly static or edge product
(Cloudflare); very tight budget with ops skill in the team (Hetzner);
Microsoft-heavy enterprise (Azure).

## 2. compute (how services run)

Options: managed containers (Cloud Run, ECS Fargate, Azure Container
Apps), Kubernetes (GKE, EKS, AKS, managed), virtual machines with docker
compose or systemd, serverless functions, edge workers.
Default: managed containers for under roughly ten services and one team;
Kubernetes when there are many services, several teams, stateful
workloads, or a need for custom networking, GPUs or operators.
Flips: "VMs" is right for one or two services, a fixed cost budget, or a
legacy runtime; wrong once you need rolling deploys, autoscaling and more
than one node, which is when Kubernetes or managed containers pay for
themselves. Serverless for spiky, short, event-driven work only.

## 3. messaging (queues and streams)

Options: RabbitMQ, Kafka (or Redpanda), NATS JetStream, cloud queues
(Pub/Sub, SQS plus SNS, Azure Service Bus), Postgres-backed queue
(transactional outbox plus a worker table), Redis Streams.
Default: a Postgres outbox or the cloud queue for task queues and
notifications under a few thousand messages per second; RabbitMQ for
routing-heavy work queues with per-message acknowledgement; Kafka only
for event streams that need replay, retention, ordering per key and
several independent consumers at high volume.
Flips: Kafka is the wrong answer for a work queue (no per-message ack,
heavy operations); RabbitMQ is the wrong answer for replay and
long retention. NATS for very low latency and simple ops.

## 4. database (system of record)

Options: PostgreSQL (managed), MySQL, MongoDB, CockroachDB or Spanner,
SQLite (embedded, single node), DynamoDB or Firestore.
Default: PostgreSQL. Flips: document-shaped data with a validator and
no joins (MongoDB); global multi-region writes (Spanner, Cockroach);
a single-tenant desktop or edge app (SQLite); serverless key-value at
scale with known access patterns (DynamoDB).

## 5. analytics store (events, reporting)

Options: ClickHouse, BigQuery, Snowflake, Postgres (small), DuckDB
(local or embedded).
Default: Postgres until events exceed tens of millions of rows; then
ClickHouse (self-hosted or cloud) for product analytics and BigQuery
when the organisation is on Google Cloud and wants zero operations.

## 6. cache

Options: Redis or Valkey (managed), Memcached, in-process cache, none.
Default: none until a measurement shows the need; then managed Redis or
Valkey. Memcached only for pure caching at very high throughput.

## 7. search

Options: Postgres full-text search, Meilisearch or Typesense,
OpenSearch or Elasticsearch, Algolia.
Default: Postgres full-text (with pg_trgm) up to a few million rows;
Meilisearch or Typesense for typo-tolerant product search; OpenSearch
for log-style or very large corpora; Algolia when budget is not the
constraint and time is.

## 8. object storage and CDN

Options: the cloud's object store (GCS, S3, Azure Blob), Cloudflare R2,
plus the cloud CDN or Cloudflare. Default: the cloud's store with its CDN;
R2 when egress cost matters.

## 9. iac (infrastructure as code)

Options: Terraform, OpenTofu, Pulumi, cloud-native (CloudFormation,
Deployment Manager), Crossplane.
Default: Terraform (or OpenTofu when the licence matters) with modules
and directory-per-environment. Pulumi when the team is stronger in
TypeScript or Python than HCL and wants tests.

## 10. ci and delivery

Options: GitLab CI, GitHub Actions, Buildkite, Jenkins; GitOps with
Argo CD or Flux for Kubernetes.
Default: the CI of the git host in use (GitLab CI on GitLab, GitHub
Actions on GitHub); Argo CD when Kubernetes is chosen.

## 11. observability

Options: OpenTelemetry with the Grafana stack (Prometheus, Loki, Tempo,
Grafana), the cloud's native suite, Datadog or New Relic or Honeycomb,
Sentry for errors.
Default: OpenTelemetry SDKs everywhere (vendor-neutral), Grafana stack
self-hosted or Grafana Cloud for a small team, Sentry for errors and
mobile crashes. Datadog when the budget allows and operations time is
scarcer than money.

## 12. auth

Options: own implementation (sessions or JWT with a well-reviewed
library), Keycloak, Auth0 or Okta, Firebase Auth or Supabase Auth,
Cognito, enterprise SSO via SAML or OIDC.
Default: a hosted identity provider (Auth0, Firebase Auth or Supabase
Auth by cloud) for consumer sign-in; Keycloak when self-hosting is a
requirement; own implementation only for simple internal tools.
Flips: enterprise customers needing SSO push toward Auth0, Okta or
Keycloak early.

## 13. api style

Options: REST with OpenAPI, GraphQL, gRPC, tRPC.
Default: REST with OpenAPI for public and mobile clients; gRPC for
service-to-service inside the cluster; GraphQL when many clients need
different shapes of the same graph and a team owns the schema; tRPC only
for a single TypeScript codebase end to end.

## 14. backend language

Options: Go, Python (FastAPI), TypeScript (Node), Java or Kotlin (Spring),
C# (.NET).
Default: the language the team already runs; with a free choice, Go for
services and APIs, Python for data and GenAI work. Flips: an existing JVM
estate or enterprise integration (Kotlin or Java).

## 15. frontend

Options: React with Vite (SPA), Next.js (SSR and SEO), Remix, SvelteKit,
Vue with Nuxt.
Default: React with Vite for authenticated apps; Next.js when SEO or
server rendering matters (marketing sites, content). Flips: a team
already on Vue or Svelte.

## 16. mobile

Options: React Native with Expo, Flutter, native Kotlin and Swift,
a responsive web app or PWA.
Default: React Native with Expo when the web team is React and the app is
forms and lists; native when the app leans on platform APIs, camera,
Bluetooth, background work, or peak performance; PWA when installation is
optional and features are web-shaped. Flutter when the team already knows
Dart.

## 17. orm and data access

Options: query builder or generated queries (sqlc, Kysely, Drizzle),
full ORM (SQLAlchemy, Prisma, GORM), raw SQL in repositories.
Default: sqlc for Go, SQLAlchemy Core style for Python, Drizzle or Kysely
for TypeScript; a full ORM only when the team asks for it and accepts
the N+1 discipline.

## 18. secrets

Options: the cloud secret manager, HashiCorp Vault, SOPS with age or KMS
in git, environment variables from the CI.
Default: the cloud secret manager; SOPS for small teams that want secrets
versioned with the infra; Vault when dynamic credentials are needed.

## 19. email, sms, push, payments

Options: email (Resend, Postmark, SES, SendGrid), SMS (Twilio, MSG91 in
India, SNS), push (FCM, APNs direct, OneSignal), payments (Stripe,
Razorpay in India, Adyen, PayPal).
Default: pick by region and volume; state the regional option when the
company's domain or PRD names a country.

## 20. analytics vendor

Options: PostHog (self-hosted or cloud), Mixpanel, Amplitude, GA4,
warehouse-only (events into ClickHouse or BigQuery).
Default: PostHog for product analytics plus the warehouse for joins;
GA4 only for marketing sites.

## 21. feature flags

Options: a flags table in the database, Unleash or Flagsmith
(self-hosted), LaunchDarkly, PostHog flags.
Default: a flags table with the `feature-flags` module for a small
team; Unleash when several services and environments need one console.

## 22. llm provider and models

Options: Anthropic Claude via the API, a cloud gateway (Vertex, Bedrock),
OpenRouter (one key and one spend limit across vendors), open models
self-hosted (vLLM) or via a host.
Default: Anthropic Claude through `llm-gateway`, tiered by task;
Bedrock or Vertex when the data must stay in a specific cloud contract;
open models only when `llm-fine-tuning` shows a cost or privacy case;
OpenRouter for prototypes, hackathons and multi-vendor comparisons where
one capped key beats several accounts. The product's calls are billed to
this key, never to anyone's Claude Code subscription.

## 23. vector store and embeddings

Options: pgvector, Qdrant, Weaviate, Pinecone, ClickHouse vectors;
embeddings from Voyage AI or an open model.
Default: pgvector in the existing Postgres up to a few million vectors;
Qdrant beyond that or for heavy filtering. Record the embedding model in
the ADR; changing it means re-indexing.

## 24. backups and dr

Options: managed automated backups with PITR, scheduled dumps to object
storage, cross-region replicas.
Default: managed backups with PITR plus a monthly restore drill; a
cross-region replica when the RTO is under an hour.

## 25. ingress and networking

Options: cloud load balancer, NGINX ingress, Traefik, a service mesh
(Istio, Linkerd), Cloudflare in front.
Default: the cloud load balancer with the managed ingress; no mesh until
mTLS or traffic splitting is a stated requirement.

## 26. speech stack

Options: a hosted speech API (Deepgram, Google Speech-to-Text, Azure
Speech, Sarvam AI for Indian languages, ElevenLabs or Cartesia for
voice), a self-hosted open model (Whisper large-v3 or turbo through
faster-whisper, pyannote for diarisation), or a telephony platform that
does both ends (Twilio ConversationRelay).
Default: a hosted streaming API for real-time voice (latency and
barge-in are the product), measured on the product's own recordings by
WER per language; self-hosted Whisper for batch transcription at volume
or when audio may not leave the client's cloud. Decide on the languages
first: Indian languages and code-mixed speech rule out some vendors.

## 27. vision approach

Options: a vision-language model through the gateway (zero training), a
pretrained model fine-tuned on labelled images (classification,
detection, segmentation), a one-class anomaly detector trained on good
images only, or a document pipeline (OCR plus layout plus a model).
Default: a VLM when the labels are open-ended and volume is low; a
trained model when the classes are fixed, volume is high or latency is
under 100 ms; an anomaly detector when defects are rare and varied.
Record the operating threshold and the cost of a miss in the ADR.

## 28. ml model family and serving

Options: a rule or statistical baseline, linear or logistic models,
gradient-boosted trees (LightGBM, XGBoost, CatBoost), a neural network,
a seasonal time-series model; served as a batch job, a Python service,
or exported (ONNX) into the calling service.
Default: gradient-boosted trees on tabular data after a baseline that
must be beaten; batch scoring unless a user waits on the answer; one
model registry entry per trained model with its data window and metrics.
