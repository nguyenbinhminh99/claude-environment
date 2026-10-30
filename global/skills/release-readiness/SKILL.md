---
name: release-readiness
description: Check whether a change or branch is ready to release - tests/build status, migrations, config and env changes, feature flags, docs - and produce release notes and a rollback plan. Use when the user asks "is this ready to ship/release/deploy/merge", wants release notes or a changelog entry, or a rollback plan. Never performs push, merge, tag or deploy itself.
argument-hint: "[branch / version / scope]"
---

# Release readiness (Release engineer)

Scope: $ARGUMENTS (default: current branch vs its base)

This skill only inspects and reports. Push, merge, tag, release and deploy require the user's explicit approval each time.

## Checklist — mark each ✅ / ❌ / ⚠️ not verified
1. **Scope**: list commits and changed files vs base; anything unrelated?
2. **Quality gates**: lint, type-check, tests, build — run them now (or cite this session's runs). CI status if `gh` is available (`gh pr checks`), read-only.
3. **Reviews**: code review and security review done? Open findings?
4. **Database**: migrations present? reversible? data-loss risk? order relative to code deploy? backup needed?
5. **Config/env**: new env vars (names only, from `.env.example`), config files, secrets the operator must set — never print values.
6. **Dependencies**: added/upgraded packages, lockfile updated.
7. **Compatibility**: breaking API/DB/UI changes, feature flags, cache/queue implications.
8. **Docs**: README/CHANGELOG/API docs updated as the project expects.
9. **Observability**: logging/metrics/alerts for the new path.

## Deliverables
- **Verdict**: READY / READY WITH RISKS / NOT READY, with blocking items.
- **Release notes**: user-facing summary + technical notes (follow the repo's CHANGELOG style if any).
- **Rollback plan**: how to revert code (revert commit/redeploy previous version), DB rollback or forward-fix, config rollback, and what signals trigger a rollback.
- **Steps for the user** to execute (push/merge/deploy commands) — listed, not run.
