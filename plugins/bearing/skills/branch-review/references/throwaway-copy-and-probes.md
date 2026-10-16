# branch-review: the throwaway copy, probes and severity

Read when you run the project check in a copy (step 3) or reproduce and calibrate findings (step 6).

3. Run the project check against the change in a throwaway copy, so
   the working tree, the branches and the worktree list end exactly as
   they began: `mkdir -p .scratch/review/<slug>/tree`, then
   `git archive <rev> | tar -x -C .scratch/review/<slug>/tree`, where
   `<rev>` is the head of the range, `HEAD` for a patch or a path, or
   the base when the range includes the working tree; then, for a patch
   or that working-tree range,
   `git apply --directory=.scratch/review/<slug>/tree <patch or diff.patch>`;
   then make the copy its own repository, because gates that list files
   through git would otherwise find the enclosing repository
   (the copy sits under its ignored `.scratch/`) and check zero files:
   `git init -q .scratch/review/<slug>/tree` (the files stay untracked,
   and a file list of cached plus untracked files sees them). Dependencies git does not
   hold are linked, never installed or copied: for a Node project
   `ln -s "$PWD/node_modules" .scratch/review/<slug>/tree/node_modules`
   (the lockfile must be unchanged in the range; when it changed, the
   check is "not run: dependencies changed in the range").
   Then `make -C .scratch/review/<slug>/tree <target>`. Record the
   command and its counts line. Keep the copy until step 6 has used it
   (a failing input can be tried there), then
   `rm -rf .scratch/review/<slug>/tree`. A check that needs what git
   does not hold and cannot be linked (a database, a service) is "not
   run" with the reason. Never test a change with git am, a new worktree, a new branch,
   a stash, or git apply into the working tree.

6. Reproduce what you can. For each confirmed Critical and High,
   when the throwaway copy from step 3 runs, write a short probe under
   `.scratch/review/<slug>/` that drives the failure through the public
   entry point (the handler, the CLI, the endpoint function) with the
   repository's own fixtures or seed data, and run it against the copy
   (`python3 .scratch/review/<slug>/probe.py`, the probe putting `tree/`
   first on its import path; or the stack's equivalent). Record the output line that shows the failure.
   A probe that does not fail sends the finding back to Questions. Then
   merge the verdicts. CONFIRMED stays at the verifier's severity.
   REFUTED moves to "Dropped" with the verifier's quoted defence.
   UNCERTAIN moves to "Questions". Medium and Low stay as the engine
   reported them, marked unverified. For each confirmed finding, say
   whether the project check from step 3 passes with it present; a
   suite that passes with a blocking bug is itself a finding (name the
   test that looks as if it covers the case and why it cannot fail:
   a boundary value far from the threshold, one call where the bug
   needs two, a principal who can never be refused).
   Calibrate severity against the deployment the repository describes:
   a race that one single-threaded writer (an ADR says so) cannot hit is
   not blocking; the same money bug reached by two ordinary sequential
   calls is.
