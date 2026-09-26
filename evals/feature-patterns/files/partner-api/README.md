# partner-api

The public API our logistics partners integrate with: catalogue, orders
and report exports. Partners exchange a client id and secret for an API
key at POST /v1/auth/token, then send `Authorization: Bearer <key>`.

Runs on EKS behind the AWS Application Load Balancer (deploy/helm). The
ALB terminates TLS and forwards the client address in X-Forwarded-For.

    go run ./cmd/api
