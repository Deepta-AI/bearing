# How a building skill uses tech-decision

1. List its decision keys at the top of its Steps ("Decisions first").
2. Call the protocol before writing any file that depends on a choice.
3. Accept the returned table; build from the Choice column, never from
   the catalogue default.
4. When a template only covers one choice (the infra templates cover
   Google Cloud and Kubernetes), say so in the ADR consequences and list
   what must be adapted for the chosen option, rather than silently
   scaffolding the covered one.
5. Never re-ask a decision that has an accepted ADR, or that the request
   or the code already settles; cite the evidence.
6. A key returned as awaiting the user is not decided. Build behind the
   recommendation only when the change is cheap to reverse, say so in the
   report under "Decisions needed", and write no ADR or decision-log row
   for it; when it is not cheap to reverse, stop at that key.
7. Write no ADR or decision-log row of the building skill's own: every
   decision record comes from `tech-decision`, and only for what the user
   decided.
