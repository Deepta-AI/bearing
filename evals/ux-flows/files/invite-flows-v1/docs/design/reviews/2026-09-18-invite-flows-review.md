# Invite flows review, 18 Sep 2026

Reviewed: docs/design/flows/team-invites/flows.md (v1). Present: product,
design, backend, support.

1. S-02: hint copy is good. Keep "Their work email".
2. S-03: finance asked that the Pro line stays word for word; it is the
   answer to the May billing tickets (ADR-0004 context).
3. S-05: show the inviter's name and the workspace name above the fold.
4. S-07: support wants the expired copy to say how long links last so
   they stop getting "the link is broken" tickets.
5. Screen design starts from these ids. Design tickets CRW-90 (S-01, S-02),
   CRW-91 (S-03, S-04) and CRW-92 (S-05 to S-07) cite them.
6. Open question 2 (join path) is scheduled as CRW-89 in backend.
7. Backend: no bulk invite endpoint this quarter. The invite API stays one
   address per call, and the per-minute limit stays as CRW-81 set it (mail
   provider reputation).
