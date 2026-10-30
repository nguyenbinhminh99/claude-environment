# <Project name>

<!-- Copy this file to the repository root as CLAUDE.md and fill it in.
     Keep it short (< 150 lines). Global rules in ~/.claude/CLAUDE.md already apply;
     only write what is specific to THIS repo. Delete sections that don't apply. -->

## Stack
- Language/runtime: <e.g. PHP 8.3, Node 20>
- Frameworks: <e.g. Laravel 11, Vue 3 + Vite, Tailwind 3>
- Database: <e.g. PostgreSQL 16> · Cache/queue: <…>

## Structure
- `<dir>/` — <what lives here>
- Entry points: <…>

## Commands (Claude runs these to verify work)
- Install: `<…>`
- Dev server: `<…>` (URL: <http://localhost:…>)
- Lint: `<…>` · Type-check: `<…>`
- Tests: `<…>` · Single test: `<…>`
- Build: `<…>`

## Conventions
- <naming, folder rules, state management, API style, i18n…>
- Branches: <…> · Commits: <e.g. Conventional Commits>

## Business rules / domain
- <rules Claude must never guess>

## Security / data
- <sensitive areas, PII fields, which environments exist; never touch production>

## Project-specific permissions
<!-- Put allow rules for this repo's safe commands in .claude/settings.json, e.g.
     {"permissions":{"allow":["Bash(npm run lint)","Bash(npm test *)"]}} -->
