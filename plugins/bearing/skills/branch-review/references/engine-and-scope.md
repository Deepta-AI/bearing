# branch-review: what the engine does and what this skill adds

Read when you wonder how this skill relates to gstack /review, /code-review or gsd-code-review.

The engine finds; a verifier who never saw the engine's reasoning
confirms. gstack `/review` (specialist reviewers in parallel, an
adversarial pass, a confidence gate) is the engine whenever it is
installed. This skill adds what this standard needs around it:
the stack checklists applied item by item, an independent verifier on
every Critical and High, the project's own check run against the change
without touching the tree, and a merge verdict.

Not this: the official `/code-review` scores findings on a GitHub PR with
several reviewers and posts an attribution line; `gsd-code-review`
reviews a GSD phase. Running gstack `/review` directly also picks up the
checklists (the session start lists them) but skips the independent
verification.
