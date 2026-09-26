# ADR-002: Run on AWS ECS Fargate

Status: Accepted (2025-03-10)

## Context
The storefront and payments already run in the company's AWS account in
ap-south-1. Nobody on the team wants to operate servers.

## Decision
We will deploy the catalogue as one ECS Fargate service with RDS for PostgreSQL 16.

## Consequences
Managed services first; anything self-hosted needs a named owner.
