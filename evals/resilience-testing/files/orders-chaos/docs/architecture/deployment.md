# orders-api: deployment

| Environment | Cluster | Namespace | Replicas | Config |
| --- | --- | --- | --- | --- |
| staging | eu-main | orders-staging | 3 | deploy/k8s/overlays/staging |
| prod | eu-main | orders-prod | 3 | deploy/k8s/overlays/prod |

Deploys: `kubectl apply -k deploy/k8s/overlays/<env>` from CI on merge (staging)
and on a tag (prod).

Redis runs in each namespace (`redis` StatefulSet, one replica, no persistence).
Postgres connection settings come from each overlay's ConfigMap.

Alerts: `deploy/monitoring/alerts.yaml`, loaded by the cluster Prometheus.
