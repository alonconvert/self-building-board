# CLAUDE.md — Project Dashboard

## Context Isolation Rules (CRITICAL)

1. **Only read the kanban file for the module you are currently working on.** Never read all kanban files at once.
2. **Module README files in `docs/modules/` are for human reference only.** Do not read them unless explicitly instructed.
3. **The PRD (`docs/PRD.md`) is for grounding only.** Read it once at session start if needed, not during builds.
4. **Each ticket gets a fresh context window.** Do not carry state between tickets.

## After Completing a Ticket

1. Update the kanban `.md` file: change `⬜ TODO` to `✅ Done`, add notes
2. Commit and push the project
3. Regenerate the dashboard: `node generate.js`
4. Commit, push, and deploy the dashboard:
   ```
   git add index.html && git commit -m "Regenerate dashboard: TICKET-ID done" && git push && npx vercel deploy --prod --yes
   ```

## Commands

```bash
node generate.js          # Regenerate dashboard from kanban data
bash build-module.sh <m>  # Build all open tickets in module <m>
npx tsc --noEmit          # TypeScript check
npx vitest run            # Run tests
```

## CRITICAL: No Local Dev Servers

**NEVER run `npm run dev`, `next dev`, or any long-running dev server.**
Push to GitHub → auto-deploy → test on live URL.
Safe to run: `npm run build`, `npm test`, `tsc --noEmit`, `eslint`, `prettier`.
