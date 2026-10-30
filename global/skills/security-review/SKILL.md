---
name: security-review
description: Security review of code changes (default - the current branch's pending changes vs its base) or of a named area - injection, authn/authz, input validation, secrets, data exposure, dependency and config risks - with severity-ranked, evidence-based findings. Use when the user asks for a security review/audit, before merging changes touching auth, payments, file upload, user input, PII or external integrations, or as part of feature-workflow review.
argument-hint: "[optional: branch, path or area; default = pending changes]"
---

# Security review

Scope: $ARGUMENTS (if empty: pending changes on the current branch vs its base branch, plus uncommitted changes)

Delegate to the `security-reviewer` subagent (read-only). Pass it: the scope (diff command or paths), what the change does, and the stack. If the scope touches auth, sessions/tokens, payments/refunds, PII or secrets, pass `model: "opus"` on that Agent call; otherwise keep its Sonnet default. Then verify its top findings yourself before reporting — drop anything you cannot substantiate.

## Determine scope
- Base branch: `git merge-base HEAD origin/main` (or `master`/`develop`, whichever exists). Diff: `git diff <base>...HEAD` plus `git diff` for uncommitted.
- Not a git repo or a named area: review those paths.

## Checklist (apply what is relevant)
- Injection: SQL/NoSQL, command, template, path traversal, SSRF, XSS (stored/reflected/DOM), unsafe `v-html`/`dangerouslySetInnerHTML`/`{!! !!}`.
- AuthN/AuthZ: missing auth checks, IDOR, role checks client-side only, mass assignment.
- Input/output: validation, file upload type/size, deserialization, open redirects.
- Secrets: hard-coded keys, secrets in logs/errors/front-end bundles, committed `.env`.
- Data: PII exposure in API responses/logs, missing encryption where expected.
- Web: CSRF, CORS, cookies flags, security headers, rate limiting on auth endpoints.
- Dependencies/config: newly added packages (known-vulnerable? typosquat?), debug mode, permissive configs. Run the ecosystem audit (`npm audit`, `composer audit`, `pip-audit`) only if available, read-only.

## Output
Findings ranked Critical/High/Medium/Low, each: file:line, issue, concrete exploit scenario, fix. Then "Checked, no issue found: …" and "Not checked: …". No findings ≠ secure — say what was out of scope.
Do not print secret values you encounter; reference the file and line only.
