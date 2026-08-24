# Repository workflow

## Change discipline

- Do not push directly to `main`.
- Create a focused branch from the latest `origin/main`, commit only in-scope files, push the branch, and open or update a pull request.
- Preserve unrelated working-tree changes.
- Run the checks appropriate to the change. At minimum, run `git diff --check` for documentation-only work; report any check that cannot run locally and rely on CI only when clearly stated.

## Decision records

- Substantial conclusions about game design, market positioning, production scope, release readiness, monetization, playtesting, or schedule must be written into the repository during the same task, not left only in chat.
- Put durable analysis in a focused document under `docs/`; update the relevant existing plan or log instead of creating duplicate sources of truth.
- Add new durable documents to the README documentation index.
- When a user requests an evaluation or makes a product decision that materially changes priorities, archive the conclusion and include it in a pull request unless the user explicitly asks for a read-only answer.
- Clearly distinguish implemented facts, developer self-test, expert heuristic review, AI simulation, and evidence from independent external players.

## Pull requests

- Prefer updating an existing open pull request when the new work has the same scope and branch history.
- Create a separate pull request when the work is independently reviewable or would make the existing pull request materially mixed in purpose.
- PR descriptions must summarize decisions, scope, risks, and verification.
