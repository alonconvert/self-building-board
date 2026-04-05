# Self-Building Board

A complete methodology and toolkit for building large software systems with Claude Code.

## Key Files

| File | Purpose |
|------|---------|
| `README.md` | Full methodology, architecture decisions, Q&A record |
| `template/` | Starter files copied by `/new-project` skill |
| `template/.github/workflows/build-module.yml` | 5-agent GitHub Actions pipeline |
| `template/generate.js` | Dashboard generator (reads GitHub API) |
| `template/CLAUDE.md` | Agent instructions template |
| `template/docs/modules/MODULE-TEMPLATE.md` | Module README template |
| `template/docs/system/` | System-level docs (Interface Contracts, Build Order) |
| `template/docs/PRD-TEMPLATE.md` | PRD template |

## Skills (in ~/.claude/skills/)

| Skill | Purpose |
|-------|---------|
| `/new-project` | One-command project setup |
| `/system-grill` | High-level system grilling |
| `/module-grill` | Deep-dive module grilling |
| `/prd-to-issues` | PRD to GitHub Issues (amended with sizing, Why, labels) |
| `/write-a-prd` | Formalize grill output into PRD |
| `/improve-codebase-architecture` | Post-module architecture health check |
