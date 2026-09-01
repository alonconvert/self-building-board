# CLAUDE.md — Self-Building Board Project

## How This Project Works

This project uses the **Self-Building Board** methodology. Tickets may be
tracked as GitHub Issues, but ordinary builds and the 5-agent pipeline run
locally. GitHub Actions is a release confirmation surface only after Alon asks
to release an exact local checkpoint.

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

1. Run the complete local proof.
2. Save a coherent local checkpoint commit in the authoritative workspace.
3. Record the local result without pushing, opening a pull request, closing a
   remote issue, or starting hosted work.
4. Only after Alon asks to release that exact checkpoint: create the temporary
   release branch, push once, run hosted confirmation, deploy if applicable,
   verify live, and retire the release branch.

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

## Local Verification

Use local builds, tests, and a bounded local dev server when UI verification is
needed. Do not auto-deploy for development. Keep no more than two persistent dev
servers across the workspace and stop a server when verification is complete.

## TDD is Mandatory

When building a ticket:
1. Write failing tests FIRST
2. Run tests — verify they FAIL (red)
3. Write minimum code to make tests PASS (green)
4. Refactor if needed
5. Run tests again — verify they PASS
6. Run `npx tsc --noEmit` — fix any type errors

Do NOT write implementation code before tests exist.
