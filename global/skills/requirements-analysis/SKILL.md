---
name: requirements-analysis
description: Turn a rough feature request, ticket or idea into user stories, numbered testable acceptance criteria (Given/When/Then), edge cases, out-of-scope items and open questions. Use when requirements are vague or incomplete, when the user asks for user stories / AC / a spec / BA analysis, or as step 2 of feature-workflow.
argument-hint: "[request or ticket text]"
---

# Requirements analysis (BA)

Input: $ARGUMENTS

For anything beyond a small request, delegate the analysis to the `ba-analyst` subagent (give it the request text and the relevant repo paths) and then review its output. For small requests, do it inline.

## Steps
1. Restate the goal in one sentence: who benefits and why.
2. Look at the existing code/docs for current behaviour, domain terms and constraints — requirements must fit what exists.
3. Write user stories: `As a <role>, I want <capability>, so that <value>.`
4. Write acceptance criteria, numbered `AC-1, AC-2…`, each testable:
   `Given <state> When <action> Then <observable result>`.
   Include validation, permissions, empty/error states, and limits.
5. Edge cases and non-functional needs (performance, accessibility, i18n, audit/logging, security/PII).
6. Out of scope — explicitly.
7. Open questions, each tagged **[blocking]** (business risk; must ask the user) or **[assumption]** (low risk; state the default you will use).

## Rules
- Never invent business rules (prices, limits, roles, legal text, workflows). Mark them as questions.
- Prefer the user's own wording and domain terms.
- If the user already gave AC, do not rewrite them — number them, then add only missing edge cases/questions.

## Output format
```
Goal: …
User stories: …
Acceptance criteria: AC-1 … AC-n
Edge cases / NFRs: …
Out of scope: …
Open questions: [blocking] … / [assumption] …
```
If there are [blocking] questions, ask the user and wait before implementation.
