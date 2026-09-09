# Repository workflow

## Collaboration agreement

- Follow `docs/COLLABORATION_PROTOCOL.md`, including the Collaboration playbook adopted in section twelve; it is the canonical agreement for Alan × Codex work.
- State the problem, expected outcome, scope, and relevant constraints. Distinguish facts, judgments, assumptions, proposals, and decisions; verify consequential AI-generated claims against sources.
- Close substantive discussions with a conclusion (or explicit deferral), unresolved questions, and actions with one owner, a due date or concrete checkpoint, and acceptance criteria. Record the decision-maker, rationale, and revisit trigger in the existing relevant document; do not create a second task queue.
- Address disagreement through evidence and trade-offs, protect confidential information, and review the process after a milestone or repeated failure. Do not add approval gates for already-authorized work or reversible implementation details.

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

## Anti-stall short-loop protocol

- Treat each reviewable outcome as one closed loop: latest `origin/main` → dedicated worktree and focused branch → targeted verification → review → commit and push → CI → merge → branch/worktree cleanup → confirm no unexpected open pull requests. Do not begin the next outcome before the current loop is closed and reported.
- Freeze the file and behavior scope before editing. Adjacent discoveries go into a follow-up note or a separate pull request unless they are required to make the current change correct. Preserve an oversized or dirty branch as read-only scratch; never keep piling unrelated fixes onto it.
- Use no more than two active agents for routine work, give them disjoint scopes, and do not allow nested delegation unless the task explicitly requires it. Stop surplus agents before testing or integration so shared-worktree edits and background commands cannot compete.
- Keep an observable progress heartbeat. If 90 seconds pass without a new artifact, test result, review finding, or resolved decision—or if the same command/approach fails twice—stop the process, capture the blocker, and reduce the scope or change the approach. Do not repeat an unchanged wait or retry indefinitely.
- Verify in ascending cost: the smallest relevant test while editing, then freeze the code, then run the full required suite once. After a failure, rerun the failing slice first; repeat the full suite only after the slice is green.
- At every handoff, state what is implemented, what was actually tested, what remains outside scope, and whether the PR was merged and cleaned up. Automated tests and developer self-test must not be described as player validation.
