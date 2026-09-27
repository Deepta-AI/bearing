# ADR-0001: Skills never push, merge, tag or deploy

Status: Accepted

## Context

Skills run inside developers' sessions with their credentials. Early
skills pushed branches and tags on their own, and one deployed a release
candidate to production from a laptop.

## Decision

No skill runs `git push`, pushes or creates a remote tag, merges a merge
request, or runs a deploy command. A skill prepares the change locally
and prints the exact commands for the developer to run. `allowed-tools`
never grants those commands; `make lint-tools` rejects the common ones.

## Consequences

Release and hotfix work ends with a printed block of commands. The
developer stays the one who publishes.
