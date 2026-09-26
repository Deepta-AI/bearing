---
name: prompt-registry
description: 'Keeps prompts in a versioned registry (prompts/<name>/vN.md) loaded by one module, with typed variables, fixture tests and scores. Use when asked to "write the system prompt", "improve this prompt" or "version prompts".'
argument-hint: "<name> [new | improve | version | audit] [python|typescript]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(uv run pytest:*), Bash(npm test:*), Bash(make:*)
---

# prompt-registry

A prompt is code that the model runs. It has a version, an owner, a
schema for its inputs, a test that renders it, and a score that says
how well the version works. An inline string in a handler has none of
those, so the registry is the only place a prompt lives, and a change
to a prompt without a new eval score is a finding, not a tweak.

## Inputs

- Solution doc: looks in `docs/genai/<name>-solution.md` for the task,
  the model tier and the success metric; if absent, asks those three
  facts in one question and continues.
- Registry and loader: `prompts/`, `app/prompts/` or `src/prompts/`; if
  absent, `new` mode creates them from `templates/`.
- Stack: `$3`, else `pyproject.toml` versus `package.json`; neither: asks.
- Model ids: the `claude-api` skill; if not installed, asks for the id.
- Eval set: `evals/<name>/`; if absent, step 8 scores a seed set of ten
  fixtures and says the full set comes from `llm-eval`.
- Gateway: `llm/` from `llm-gateway`; if absent, the loader returns
  the rendered text and frontmatter for a direct SDK call, and the
  gateway is noted as a follow-up.

## Steps

1. Name and mode from `$ARGUMENTS`. Modes: `new` writes `v1`; `improve`
   writes `v<N+1>` from the current version; `version` promotes a draft;
   `audit` only reports. No mode: `audit` when `prompts/` exists, else
   `new`. Stack from `$3` or from `pyproject.toml` versus `package.json`.
   Load the `claude-api` skill for the current model ids and parameter
   shapes before writing frontmatter or loader code.
2. Registry layout: `prompts/<name>/v<N>.md` from `templates/prompt.md`,
   `prompts/<name>/fixtures.json` (one fixture per named case, every
   variable filled), `prompts/<name>/CHANGELOG.md`. The loader is one
   module per stack from `templates/prompts-module.md`
   (`app/prompts/__init__.py` or `src/prompts/index.ts`). Create what
   is missing; never a second loader.
3. Frontmatter: `model` (exact id), `effort`, `max_tokens`, `variables`
   (name, type, required, max_chars, enum where it applies), `owner`,
   `eval_set` (path under `evals/`), `status` (draft, active,
   retired). No `temperature`: current models reject it; a pinned older
   model may carry it with a comment saying why.
4. Body in the order in `references/prompt-structure.md`: role, task,
   inputs inside delimiters, constraints, output format as a schema,
   examples, refusal and escalation rules, injection defence lines.
   Every variable in the body appears in the frontmatter and vice versa.
   An output the code will parse is a JSON schema in the prompt and
   `output_config.format` in the call, not "respond in JSON".
5. `improve`: read the eval failures (`evals/<name>/last-run.md` or the
   user's examples) before touching the text. Then run the wording
   review: invoke the `claude-api` skill with `prompt-audit`, scoped to
   `prompts/<name>/v<N>.md` and targeting the frontmatter `model`. It
   returns findings (file:line, pattern, reason, confidence) and a
   proposed diff; it does not apply edits. Take the findings that match
   an eval failure, or are high confidence, into `v<N+1>`, never
   editing `v<N>`. Change one section per version and write in the
   changelog what changed, why, which failures and which audit findings
   it targets. Never edit a version with status `active`. One section
   per version is for tuning wording against a score; it never holds
   back injection defence. An untrusted value (user text, a document,
   or a field the code read from a document) that reaches the model
   undelimited is a defect: the version you are writing delimits it and
   adds the data line; in a prompt you are not changing, report it as a
   finding naming the route. `claude-api`
   not installed: say so in the report and review the wording against
   `references/prompt-structure.md` alone.
6. Render rules in the loader: validate the variables against the
   schema (missing, unknown, oversized, not in enum) and fail before the
   model call; substitute `{{name}}` only; escape a closing delimiter
   tag found inside a value. The delimiters live in the version's body,
   not in the loader, so a moved prompt renders byte for byte as before;
   return the rendered text with the
   frontmatter so the caller passes `model`, `effort` and `max_tokens`
   from the prompt, not from code.
7. Tests: one test renders every prompt in the registry with its
   fixtures and asserts no placeholder remains; one asserts every
   `variables` entry is used in the body; one asserts the loader
   rejects an oversized and an unknown variable. Print the count of
   prompts rendered. Zero prompts: the test fails.
8. Eval: run `llm-eval` on the eval set for the new version and
   write the score into `CHANGELOG.md`. No eval set yet: score the ten
   fixtures with a deterministic check (renders clean, output matches
   the declared schema), write it as `seed: x/10`, and say the full set
   comes from `llm-eval`. A version promoted to `active` without a
   score is a finding. A score below the previous version
   keeps the previous version active.
   Moving inline prompts into the registry: `v1` is the old wording
   unchanged, and the move is proven behaviour-neutral for every prompt,
   by the recording's hash where one exists and otherwise by comparing
   what the old strings and the new loader send (system, user, model,
   max_tokens) for the same inputs. The requested fix is `v2`, draft
   until scored.
9. `audit`: two passes. Registry pass (this skill): grep the code for
   `system=`, `system:`, `"role": "system"`, `role: "system"` and
   string literals over 200 characters near a `messages.create` or
   `toolRunner` call outside the prompts module; each hit is an inline
   prompt, reported with file and line; then the registry versions
   without a score. Wording pass (the `claude-api` skill, `prompt-audit`):
   scope is every `active` version in the registry plus the inline hits,
   target model from each prompt's frontmatter; report its findings
   (file:line, pattern, confidence) and keep its proposed diff as a
   proposal for `improve`, never applied here. Print "prompts audited:
   N"; N=0 with no inline hits is "0 prompts found; nothing to audit",
   not a pass. A finding states what breaks, leaks or is misreported
   and cites file:line (an absence names the path looked for). A scored
   prompt that follows the rules is not a finding for lacking an
   optional section; mention such ideas once, as optional. Check what
   actually decides the running version (a call site that pins a version
   number ignores `status`) and whether each recorded score's eval set
   exists in the repository. A claim about model or API behaviour you
   did not verify is labelled unverified, never a blocker.
10. Print the output contract.

## Output contract

```
## Prompt: prompts/<name>/v<N>.md (<new | improve | version | audit>)
model: <id>   effort: <level>   max_tokens: N   variables: N   owner: <name>
status: draft | active   eval: <score> on <eval_set> | NOT RUN (finding)
changelog: <one line for this version>
tests: <N> prompts rendered, <M> fixtures, variables check passed | failed
audit: <K> inline prompts in code (file:line ...), <J> versions without a score
wording: <N> prompts audited by claude-api prompt-audit, <F> findings (<H> high), diff proposed | not run (<reason>)
```

## Gotchas

- A prompt in a Python f-string or a template literal cannot be versioned
  or evaluated. Move it; do not "just fix it in place".
- Do not template with `str.format` or `${}`: JSON schemas in the body
  carry braces. Substitute `{{name}}` with a strict regex.
- Delimit every user-supplied variable and say in the prompt that text
  inside the delimiters is data. That is the first injection defence.
- Changing the model without a new version is a version. The score
  belongs to the pair (prompt text, model), not to the text alone, and
  not to code that edits the output afterwards: a post-call correction
  is scored and reported separately, as a change to what the function
  returns, with its own test.
- A stable prompt goes first in `system` with `cache_control`; the
  variables go after the cache breakpoint or in the user turn.
- Fable 5.1 and Opus 5 do best with fewer prescriptive lines. A prompt
  written for an older model often reads as too many rules; cut before
  adding.
- No em dashes in prompts either; they leak into the model's output.
- The wording review belongs to `claude-api`'s `prompt-audit`; the
  registry, versions, render tests and scores belong here. An audit
  finding becomes a new version with a new score, never an edit in
  place, and a finding that lowers the score is reverted.
