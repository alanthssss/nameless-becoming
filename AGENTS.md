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

## Workspace hygiene

- At task start and final handoff, inspect `git status`, branch/HEAD, worktrees, upstream divergence and open PRs. The default checkout should rest on clean, current `main`; implement in a dedicated worktree.
- After an authorized merge and successful checks, delete the merged task branch remotely and locally, remove its clean temporary worktree, prune stale worktree metadata, and fast-forward the default checkout. Never push directly to `main` or force-reset unrelated work.
- Before archiving dirty or unmerged work, save a binary patch and a verified Git bundle outside the repository, record recovery instructions, and retain any untracked or ignored user artifacts. Only delete branch refs after their exact tips are recoverable.
- Keep unresolved design/product choices as explicit draft PRs; do not merge or close them solely to make the PR list empty. Ready implementation PRs still require review and their appropriate checks. Cleaning is not product approval.
- Keep active worktrees only for ongoing work. Relocate historical checkouts with useful ignored artifacts into a clearly named archive rather than silently deleting those artifacts. Do not switch or remove a worktree being used by another active task.
- Apply this hygiene during each task and after delivery; do not claim continuous background monitoring unless an automation has actually been configured.

## Production stages and bounded execution

- Read [the production paradigm](docs/design/swarm-flight-production-paradigm.md) and the latest Now before continuing Swarm Flight work. Stabilize a representative element before extending levels; follow P0–P5 and evidence gates G0–G5. Keep one execution state in Now and version-specific evidence in the existing batch receipt. A document, commit, passing CI or finished turn does not advance a gate.
- Keep every complete task turn under ten minutes, including reading, waits, subagents and handoff. Plan one result within eight minutes, save at minute eight and finish before nine minutes thirty seconds. Split risky work beforehand; use actual complete-turn timing, not partial tool observation. Unverified prompt-only automation is not a hard time limit; the paused continuation must not resume without later authorization and verified execution/cutoff handling.
- For element changes, preserve editable sources, stable identity/version, tested variation limits and affected usage sites. Fix and verify the source before updating instances. Keep current gameplay stable and player-facing seasons/solar-term names absent; the product target is 24 levels, while legacy numbering and evidence remain intact until a deliberate mapping/migration is implemented.

## Visual coherence and physical plausibility

- Apply [GDD §8.1 visual production rules](docs/design/swarm-flight-gdd.md#visual-production-rules) to every new or revised scene, asset, effect and animation. Preserve the approved hand-painted garden style; historical prototype material standards do not override the current GDD.
- Check objects together in the running game: consistent linework, palette, light, scale and detail; credible plant attachments, support, hanging points, gravity, wind response and occlusion; visible affordances must agree with collision and weather rules. Stylization may simplify natural structure, but cannot conceal an unexplained broken connection or contradict the same object's behavior.
- Review affected states at actual play scale and in continuous movement, including before/after interactions and relevant adjacent scenes. Floating props, disconnected stems, unsupported loads, mismatched visual/collision shelter, or abrupt style changes are defects to resolve internally before candidate delivery. Record native evidence and remaining gaps; automated checks or a single attractive still do not establish visual acceptance.

## Swarm Flight completion and regression checks

- For every authored or revised level, apply [SF-R35's level-flow checklist LV01–10](docs/design/swarm-flight-game-20261020.md#level-flow-checklist). Record pass / fix / not-applicable with reasons and evidence in the existing batch decision or build receipt. Preserve each chapter's theme; the checklist is not a fixed encounter template. Separate technical verification from player experience and resolve known basic defects before delivery; no per-item user approval is required.
- Preserve the active parent goal in the existing Now view. Internal repairs do not complete product milestones or reset their checkpoints. Batch ordinary defects within the authorized delivery; do not ask Alan to verify each basic rule.
- For changed mechanics, derive expected observable behavior from the player rule before inspecting implementation; test relevant ordinary-input states, explicit exemptions and environmental combinations. Reproduce the user's actual path before asserting a cause. Existing tests may encode the same mistaken assumption as the code.
- Swarm Flight CI runs `scripts/check_swarm_regressions.py`: baseline must pass and isolated copies with known wind defects must fail the specific behavior assertions. Crashes and parser errors cannot count as caught regressions. Review changed mutation anchors and expected assertions independently.
- For SF-R23 milestone claims, run `tools/check_delivery.py` against `prototypes/swarm-flight/delivery-contract.json`, an evidence receipt and the frozen full commit. `maintenance` is internal work; `candidate` requires every product criterion; `accepted` additionally requires actual user feedback. CI testing this checker is not product acceptance. Read the evidence and its source: schema/hash validation cannot establish truth, art quality or enjoyment. Do not delete criteria merely to pass; scope changes must update the original decision.
- For the authorized03→05 recovery candidate, use `tools/package_spring_review.py` and the scoped contract defined in GDD§13.5. Internal exports are for development; maintenance receipts and known-answer route tests cannot authorize a player-review package. Preserve the full-game contract. Packaging integrity does not certify review truth or enjoyment. Do not bypass this entry with an ad-hoc walkthrough-bearing package.
- The delivery checker originates in the owned `godot-production-workflow` skill. When updating it, synchronize the skill source, this copy and their tests. Do not alter gameplay or publish a new build merely to demonstrate these tools.

## Swarm Flight commercial accountability

- At the start and close of every production batch, including internal fixes and process work, consult SF-R17's commercial limits and the current Now view. Include a short commercial status in the delivery: product outcome, measured effort and its coverage, cumulative/remaining forecast and uncertainty, new cash/fees, and continue/review decision. Do not omit this because CI passed.
- Keep cost in the existing build receipt's `cost` and SF-R23 `production_forecast` evidence. Start recording main-task/subtask work intervals before work, distinguish execution from external waiting, and preserve unknown history. Observable elapsed time, active work, billed usage and cash are different quantities; never convert one into another without evidence. Missing cumulative data means remaining budget is unknown, not 240 hours available or zero used.
- The 200 + 40 hour control limit remains in force pending an explicit product decision; calling it historical or uncalibrated does not reset or remove it. If comparable accumulated effort/forecast cannot be established, report the budget as unverifiable. Continue only the already-authorized representative sample and necessary integration, not additional scope, bulk art production or new spending justified by alleged remaining budget.
- At the next whole-package checkpoint, read the actual `production_forecast` report for effort coverage, historical gaps, remaining work, variance/unknowns, cash and a continue/change/stop recommendation. A report file's existence is insufficient. Preserve SF-R23's single concentrated revision limit; sample failure or forecast over 240 hours triggers concrete scope/production/date tradeoffs, not automatic extension. Never silently shrink the game or lower basic quality.
