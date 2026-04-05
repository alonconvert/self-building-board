# CLAUDE.md — Self-Building Board Project

## How This Project Works

This project uses the **Self-Building Board** methodology. Tickets are GitHub Issues. Builds run via GitHub Actions. A 5-agent pipeline handles each ticket: Researcher, Quality Architect, Coder, Reviewer, QA.

## Context Isolation Rules (CRITICAL)

1. **Work on ONE issue at a time.** Fetch only the issue you are currently building with `gh issue view <number>`.
2. **Module README files in `docs/modules/` are for the Researcher agent only.** Other agents work from briefings, not raw READMEs.
3. **The System PRD is for grounding only.** Read it once at session start if needed, not during builds.
4. **Each ticket gets a fresh context window.** Do not carry state between tickets.
5. **Interface Contracts (`docs/system/interface-contracts.md`) define cross-module boundaries.** Respect them. Don't change them without explicit approval.

## Agent Roles (when running in the pipeline)

- **Researcher:** Read the codebase + module README + Interface Contracts. Produce a briefing file. Do NOT write code.
- **Quality Architect:** Read the briefing + ticket. Define TDD test specs + quality criteria. Write to QA spec file. Do NOT write code.
- **Coder:** Read both briefing files. Write tests FIRST (TDD), then implement. Follow existing code patterns.
- **Reviewer:** Check code against ticket spec. Output `REVIEW: PASS` or `REVIEW: FAIL` with feedback. Do NOT fix code.
- **QA:** Comprehensive audit — tests, edge cases, efficiency. Output `QA: PASS` or `QA: FAIL` with feedback. Do NOT fix code.

## After Completing a Ticket

1. Commit and push the code
2. Close the GitHub Issue: `gh issue close <number> --comment "Built: <summary>"`
3. Push to trigger dashboard update

## Commands

```bash
npx tsc --noEmit          # TypeScript check
npx vitest run            # Run tests
gh issue view <n>         # Read a ticket
gh issue close <n>        # Mark ticket done
gh issue list --label "module:<m>" --state open   # List open tickets for a module
```

## System Context

```
docs/system/interface-contracts.md    # Cross-module contracts (handshakes)
docs/system/build-order.md            # Module dependency layers
docs/modules/<module>.md              # Module README (Researcher reads this)
```

## CRITICAL: No Local Dev Servers

**NEVER run `npm run dev`, `next dev`, or any long-running dev server.**
Push to GitHub -> auto-deploy -> test on live URL.
Safe to run: `npm run build`, `npm test`, `tsc --noEmit`, `eslint`, `prettier`.

## TDD is Mandatory

When building a ticket:
1. Write failing tests FIRST
2. Run tests — verify they FAIL (red)
3. Write minimum code to make tests PASS (green)
4. Refactor if needed
5. Run tests again — verify they PASS
6. Run `npx tsc --noEmit` — fix any type errors

Do NOT write implementation code before tests exist.
