---
name: ui-implementation
description: Design and build user interfaces — user flows, screen layout, components, states, responsive behaviour and accessibility — in the project's existing front-end stack, then verify visually. Use when a task adds or changes a screen, page, form, component or styling, or when the user asks for UI/UX design, a mockup or a prototype.
argument-hint: "[screen / component / flow]"
---

# UI implementation (UI/UX)

Target: $ARGUMENTS

## 1. Find the existing UI system first
Framework (Vue, React, Blade, plain HTML…), component library, CSS approach (Tailwind, SCSS, CSS modules…), design tokens, icons, i18n, existing similar screens. Reuse them. Do NOT introduce a new UI framework or CSS library.
- No front-end yet / standalone prototype: prefer plain HTML + CSS, or Vue SFCs if the project is Vue or the user wants Vue.

## 2. Design before code (for new screens/flows)
- User flow: entry point → steps → success/exit, including error and cancel paths.
- Screen spec: layout regions, components, content hierarchy, primary action.
- States: loading, empty, error, success, disabled, permission-denied, long text/overflow.
- For a big new flow, show the user a short spec or a static HTML mockup and get confirmation before wiring logic.

## 3. Build
- Semantic HTML; labels on every input; keyboard reachable; visible focus; contrast ≥ WCAG AA; alt text.
- Responsive: check ~375px mobile and desktop. No horizontal scroll.
- Copy: match the product's language and tone; no lorem ipsum in shipped UI.
- Keep logic out of templates where the project separates it.

## 4. Verify
- Run the project's lint/type-check/unit tests for components.
- Look at it: dev server + browser (or a screenshot tool if available) at mobile and desktop widths; exercise each state. If you cannot view it, say "visual not verified".
- For notable UI changes, ask the `ui-reviewer` subagent to review (read-only) and fix what it finds.

## Output
Files changed, screenshots/what was checked at which widths, states covered, accessibility notes, anything not verified.
