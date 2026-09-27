# 3. Ship billing-portal to on-prem customers as a Docker image

Status: Accepted (2025-06-12)

## Context

Three enterprise customers cannot send invoice data to a hosted service.
They asked to run billing-portal inside their own network.

## Decision

We publish the production image built from the Dockerfile to the customer
registry. Customers pull it and run it on their own servers. The image
contains the application and its production dependencies (`npm ci
--omit=dev`); development tooling is not in the image.

## Consequences

- Every production dependency is now redistributed to customers, not only
  run by us. Its licence terms apply to that distribution.
- The image is proprietary; customers receive it under our commercial
  licence and do not receive our source code.
