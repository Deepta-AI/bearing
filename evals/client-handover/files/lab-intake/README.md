# lab-intake

Lab-report intake for Harbor Clinics. Partner labs POST signed report
webhooks; the service parses each report, stamps a PDF copy, files it
against the patient record in Postgres and emails the clinic.

Current release: v1.3.0

## Environments

- Staging: https://staging-intake.harborclinics.example.net
- Production: https://intake.harborclinics.example.com

## Running locally

    cp .env.example .env
    make run

## Checks

    make check

## Deploying

`make deploy ENV=staging` or `make deploy ENV=production`. CI runs the same
target on main (staging) and on tags (production).

## Design

See docs/design/hld.md.
