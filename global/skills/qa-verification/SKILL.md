---
name: qa-verification
description: Plan and run verification for a change — test plan mapped to acceptance criteria, automated unit/integration/e2e tests, regression checks, lint/type-check/build, and UI checks — and report evidence honestly. Use after implementing something, when the user asks to test, verify, write tests, check regressions or "make sure it works", or as step 5 of feature-workflow.
argument-hint: "[what to verify / AC list]"
---

# QA verification

Scope: $ARGUMENTS

## 1. Discover how this repo tests
Find the real commands (package.json scripts, composer.json, Makefile, phpunit.xml, pytest.ini, CI workflow files). Use those exact commands. Note the test framework and where tests live.

## 2. Test plan
Table: `AC-id | scenario | type (unit/integration/e2e/manual) | test file or check`.
Include negative cases, boundaries, permissions, and regression of nearby existing behaviour.

## 3. Write/extend tests
- Follow the existing test style and helpers. Tests must fail without the change and pass with it when practical.
- Delegate test writing to the `qa-tester` subagent for larger suites — assign it specific test files; it must not edit production code.

## 4. Run
Lint → type-check → tests (targeted, then full suite if reasonable) → build. For UI, view it in a browser at mobile + desktop width when tools allow.

## Hard rules
- Never claim a pass you did not observe in this session's output.
- Never skip, delete, `.only`/`.skip`, loosen assertions, raise timeouts blindly, or disable lint rules to get green. If a test seems wrong, explain and ask.
- Pre-existing failures: check whether they also fail without your change (CI history, or a separate clean checkout/worktree; ask before stashing or resetting anything) and report them separately.
- Flaky test: re-run once, report it as flaky; don't hide it.

## Output
```
Test plan: (table)
Commands: <cmd> → pass/fail (counts)
AC coverage: AC-1 ✅ test_x · AC-2 ⚠️ manual only · AC-3 ❌ failing (why)
Pre-existing failures: …
Not verified: …
```
