---
name: feature-workflow
description: End-to-end delivery workflow that coordinates the AI dev team (BA, architect, UI/UX, developer, QA, code and security review, release readiness). Use when the user asks to build, add, change or implement a feature, user story, ticket or requirement — especially when they give acceptance criteria — in any repository. Not for one-line fixes, pure questions, or reviews of existing code.
argument-hint: "[feature request / acceptance criteria]"
---

# Feature workflow

Request: $ARGUMENTS

You are the lead developer and orchestrator. You write the code; subagents analyse, design-check, test and review. Scale the process to the task — do not run every step for every request.

## 0. Triage (always, takes one line)
Classify and state it:
- **S (small)**: ≤ ~3 files, no new data model/API, clear AC → skip to step 4, then 5 and a quick self-review.
- **M (medium)**: new endpoint/screen/component, some ambiguity → steps 1–7, agents only where they add value.
- **L (large/risky)**: data model or migration, auth/payments/PII, cross-module, external integration → all steps, with confirmation gates.

Model routing for the tiers (see global CLAUDE.md): S → stay on the session model (Sonnet). M → Sonnet; use `architect` (Opus) only if the design is non-obvious. L or ambiguous → enter plan mode for analysis/planning (Opus under `opusplan`), get the plan approved, then implement outside plan mode (Sonnet). Escalate reviewers to `model: "opus"` only for high-risk changes.

## 1. Understand the repo
Read the project's CLAUDE.md/AGENTS.md, README, manifests, and code near the change. Identify stack, test/lint/build commands. Never assume a stack.

## 2. Requirements (M/L) — skill `requirements-analysis`, agent `ba-analyst`
Output: user stories, numbered acceptance criteria (AC-1…), edge cases, out-of-scope, open questions.
**Gate:** if any open question has business risk (money, data, permissions, legal, user-visible behaviour not specified), STOP and ask the user. Do not invent rules.

## 3. Design (M/L) — skills `architecture-review`, `ui-implementation`
- Backend/data/API/integration/security-relevant → agent `architect`.
- UI → follow `ui-implementation`; get flow/screen sketch if the AC imply new screens.
These two can run in parallel when independent.
**Gate (L):** present the design summary (data model, API contract, migration plan, risks) and wait for user confirmation before coding.

## 4. Plan and implement (you)
- Write a short plan: ordered steps, files to touch, tests to add, mapped to AC IDs.
- Implement in small steps. Follow existing patterns. Add/adjust tests with the code.
- Only you edit production code. If `qa-tester` writes tests, it only touches test files you assign, and never at the same time as you edit those files.

## 5. Verify — skill `qa-verification`, agent `qa-tester`
Run the project's real lint/type-check/test/build. For UI, check it renders (browser or screenshot when available). Map each AC to evidence (test name or manual check). Fix failures; never weaken tests.

## 6. Review (M/L) — agents `code-reviewer` and `security-reviewer` in parallel
Give both the diff scope (`git diff <base>...HEAD` or the list of changed files) and the AC. They are read-only. Triage their findings: fix real issues, explain dismissed ones. Re-run tests after fixes. Use `ui-reviewer` too when UI changed.

## 7. Release readiness (when the change will ship) — skill `release-readiness`
Checklist, release notes, rollback plan. Do NOT push/merge/deploy without explicit approval.

## Final report (always)
```
Summary: what was built (1–3 lines)
AC status: AC-1 ✅ (test: …) · AC-2 ✅ (manual: …) · AC-3 ⚠️ not verified (why)
Files changed: …
Commands run: <cmd> → <result>
Review findings: fixed / dismissed (reason) / open
Not verified / risks / follow-ups: …
Needs your decision: …
```
