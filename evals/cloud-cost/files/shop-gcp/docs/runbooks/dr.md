# Disaster recovery

pg-replica-dr is a cross-region Cloud SQL read replica of pg-primary in
asia-south2 (Delhi). It exists for regional failover: RPO 5 minutes, RTO 1
hour, as agreed with the merchants in the service terms.

Failover: promote pg-replica-dr, point the api and reports at it, and scale
the prod node pool in asia-south2 from the standby template.

Do not resize, stop or delete the replica without the platform lead; a
replica smaller than the primary cannot take the production load after a
failover.
