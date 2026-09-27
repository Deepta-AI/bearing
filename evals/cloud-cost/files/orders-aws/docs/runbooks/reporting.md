# Nightly reporting batch

The reporting batch runs on the EC2 instance reporting-batch
(i-0f9a3reporting1, m5.4xlarge) from terraform/reporting.tf. A cron job on the
instance starts at 01:00 IST and usually finishes by 01:40; it builds the
finance and merchant settlement reports from a read of orders-db-prod.

The instance is idle the rest of the day. It is owned by the finance
engineering team.
