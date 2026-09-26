# claimdesk

Expense claims for our own staff: an employee records a claim with its
receipt, it gets approved, and finance pays it with the next payroll run.

Today this is a small Python service (stdlib only) with the claim model and
the rules; the web front end is being built next.

## Layout

- `claimdesk/models.py`: users and claims
- `claimdesk/claims.py`: creating, submitting and deciding claims
- `claimdesk/config.py`: limits and the auto-approval threshold
- `docs/product/PRD.md`: what the claims product must do (v1.0)
- `docs/adr/`: decisions already taken

## Policy notes

Auto-approval follows finance policy FP-12: small claims (below INR 500)
skip approval. Finance owns that number; change it in `config.py` only
with their sign-off.

## Checks

    make check
