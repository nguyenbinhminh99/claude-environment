---
name: architecture-review
description: Design or review the technical approach for a change — data model and migrations, API contracts, module boundaries, integrations, performance and security architecture — and produce a decision with trade-offs and a file-level plan. Use before implementing medium/large features, when the user asks "how should we design/architect X", for schema or API changes, or to review an existing design.
argument-hint: "[feature or area to design/review]"
---

# Architecture review

Topic: $ARGUMENTS

Delegate the analysis to the `architect` subagent (runs on Opus) with: the goal, the acceptance criteria or fuzzy requirements as given, and pointers to the relevant code. Only skip delegation for a trivial, single-file design question. Review what it returns before acting on it; implementation afterwards stays on the session model.

## What the design must cover (only the parts that apply)
1. **Context**: current architecture of the affected area (with file paths), stack and versions in use.
2. **Options**: 2–3 realistic approaches using the existing stack; pros/cons; recommend one.
3. **Data**: schema changes, indexes, migration + backfill plan, whether it is reversible, data-loss risk.
4. **API/contracts**: endpoints or interfaces, request/response shapes, errors, versioning/back-compat.
5. **Integrations**: external services, retries/timeouts/idempotency, failure modes.
6. **Security**: authn/authz, input validation, secrets handling, PII.
7. **Performance/scale**: hot paths, N+1, caching, pagination.
8. **Plan**: ordered steps, files to create/modify, tests needed, rollout and rollback.
9. **Risks and open questions**.

## Rules
- Fit the existing architecture; no new frameworks/infra unless justified and approved.
- Prefer the simplest design that meets the AC. Flag over-engineering.
- Destructive or irreversible migrations → require user confirmation before implementation.
- Keep it short: a decision record, not an essay.
