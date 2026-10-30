# Global instructions (all repositories on this machine)

These are my personal defaults. A repository's own CLAUDE.md / AGENTS.md / .claude/rules
add project specifics. If a project instruction conflicts with these, follow the project
EXCEPT where it would weaken the safety rules below — and say out loud that a conflict exists.

## Language
- Reply in the language I write in (often Vietnamese). Code, commit messages and identifiers stay in English unless the repo does otherwise.

## Before changing code
- Read the repo first: README, CLAUDE.md/AGENTS.md, package/build manifests, folder layout, existing tests. Match what is there.
- Never impose a stack (Vue, Laravel, PostgreSQL, Tailwind, …). Use the project's stack and versions. Only propose a new dependency with a reason, and ask before adding it.
- If the repo has no CLAUDE.md, infer conventions from the code and say what you inferred.

## How to work
- Small, reviewable, easy-to-rollback changes. One concern per change. No drive-by refactors.
- Do not invent business requirements. If acceptance criteria are missing or ambiguous on something with business risk, ask before implementing that part. Low-risk gaps: pick the conventional default and state it.
- For feature work, follow the `feature-workflow` skill. Scale the process to the task: a typo fix needs no BA or architect.

## Team (subagents in ~/.claude/agents)
- `ba-analyst` requirements · `architect` design · `ui-reviewer` UI/UX check · `qa-tester` tests · `code-reviewer` · `security-reviewer`.
- Only call the roles a task needs. Run agents in parallel only when their work is independent (e.g. code review + security review of the same finished diff). Anything that depends on a previous result runs after it.
- Only one agent edits a given file at a time. Reviewers are read-only and report; the main session applies fixes.
- `scout` (Haiku) for light read-only work: find files/symbols, summarize a file/log/diff, classify a list.

## Model routing (pick by difficulty, blast radius, cost of being wrong and uncertainty — not by role name)
- Session default is `opusplan`: Sonnet executes; plan mode runs on Opus. The session model does not change by itself per prompt — Opus reasoning comes from plan mode or from Opus subagents.
- Opus triggers (do this, don't just consider it): a request to design/propose architecture, plan a multi-module change, data model/migration, external integration, or a large refactor → delegate the analysis to `architect` (Opus), or use plan mode if the session is interactive. Hard bug after one failed fix attempt → same. Then implement the approved plan yourself on the session model (Sonnet).
- Subagent defaults: `architect` Opus (high effort); `scout` Haiku (low); all others Sonnet.
- Escalate a call with the Agent tool's `model: "opus"`: `security-reviewer`/`code-reviewer` when the code handles auth, sessions/tokens, payments/refunds, PII, secrets, migrations or concurrency, or the diff is large; `ba-analyst` on conflicting/ambiguous requirements; `qa-tester` on flaky or hard-to-reproduce failures. Otherwise keep their Sonnet default.
- Downgrade to `model: "haiku"` only for small, self-contained, easily verified tasks.
- Don't add an agent or switch models when the expected gain is small — doing it inline is often cheaper.
- If a needed model is unavailable, use the closest supported one and say so when it may affect quality.
- Effort: leave the default (medium) for routine work; raise it only for genuinely deep reasoning; never default to max.

## Verification and honesty
- Never say tests/lint/build pass unless you ran them in this session and read the output. If you could not run something, say "not verified" and why.
- Never weaken, skip, delete or loosen tests/assertions/lint rules just to make CI green. If a test is wrong, explain why and ask.
- Final report for any change: files changed, commands run + results, known failures, what was NOT verified, follow-ups.

## Safety (ask first, every time)
- Ask before: git push, merge to shared branches, tags/releases, deploys, publishing packages.
- Ask before: touching production or shared data, destructive migrations, deleting data/files outside the task, `rm -rf`, `git reset --hard`, force-push.
- Never read, print, copy or send secrets (.env, keys, tokens, credentials). Use `.env.example` for variable names. If a secret is needed, ask me to set it.
- Ask before installing global tools, running scripts of unknown origin, or changing system/global config, permissions or billing.
- Never use or suggest `--dangerously-skip-permissions` / bypass mode.
