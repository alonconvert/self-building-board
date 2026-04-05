# The Self-Building Board — A Methodology for Building Large Projects with Claude Code

A repeatable system for taking a project from idea to production using Claude Code. Designed for non-developers who direct AI agents to build software.

---

## Overview

This system turns a project idea into a fully tracked, one-click buildable production codebase. The lifecycle is:

```
Grill → Kanban Tickets → Dashboard Board → Build Cycle → Module Review
```

Each phase feeds the next. Nothing is skipped. The output of every phase is a concrete artifact — not just a conversation.

---

## Phase 1: Grill

**What it is:** An intense interview session where Claude asks you questions about what you want to build. The goal is to extract every requirement, edge case, and decision before any code is written.

**How to run it:** Use the `/grill-me` skill in Claude Code. Tell it what you want to build. It will ask you questions until it fully understands the system.

**Output:** A structured understanding of:
- What the system does
- Who uses it
- What modules it breaks into
- How modules connect to each other
- External APIs and integrations
- Business rules and constraints

**Important:** The grill output feeds directly into two things: the PRD and the module README files. Don't skip this — the quality of everything downstream depends on how thorough the grill is.

---

## Phase 2: PRD + Module READMEs

### PRD (Product Requirements Document)

**What it is:** A single document that describes the entire system at a high level. Lives at `docs/PRD.md`.

**Purpose:** The PRD is the "why" and "what" — not the "how." It exists so anyone (human or agent) can quickly understand what the project is supposed to do.

**Template:** See `template/docs/PRD-TEMPLATE.md`

### Module README Files

**What they are:** One detailed README per module, living at `docs/modules/<MODULE>.md`. These are the deep-context documents that preserve everything discussed during the grill.

**Critical annotation:** Every module README starts with:

```
> **HUMAN REFERENCE ONLY** — This file preserves the full context, decisions, and intent
> behind this module. Agents should NOT read this file unless explicitly instructed.
> The operational spec for agents is in the kanban tickets.
```

**Why this matters:** Agent context windows are limited. Module READMEs contain rich context that's valuable for humans to refer back to, but would bloat an agent's context if loaded during a build. Agents work from kanban tickets, not from these files.

**What they contain:**
- Module purpose and scope
- Decisions made during the grill (and why)
- What this module connects to (other modules, external APIs)
- Edge cases discussed
- User stories and workflows
- Anything that might get lost if only the tickets exist

---

## Phase 3: Kanban Tickets

**What they are:** Markdown files with ticket tables — one file per module. Live at `docs/kanban/<module>.md`.

**This is what agents actually read.** Each ticket is a self-contained unit of work.

**Format:**
```markdown
# Kanban — <Module Name>

Spec: `docs/modules/<MODULE>.md`

### Phase 1 — <Phase Name>

| ID | Title | Status | Notes |
|----|-------|--------|-------|
| MOD-01 | Short description of what to build | ⬜ TODO | |
| MOD-02 | Another ticket | ✅ Done | What was built. |
```

**Rules:**
- One file per module — never combine modules
- Ticket IDs use the module prefix: `META-01`, `RPT-01`, `ONB-01`, etc.
- Completed tickets are marked with `✅ Done` in the Status or Notes column. Any ticket row without `✅` is treated as open by the build system — so `⬜ TODO`, blank status, or any other text all count as "not done yet"
- Notes column is filled in by the agent after completing the ticket
- Phases group related tickets — infrastructure first, then features, then tests

**Context isolation rule:** Agents should ONLY read the kanban file for the module they are currently working on. Never read all kanban files. This prevents context bloat.

---

## Phase 4: Dashboard Board

**What it is:** A single-page HTML dashboard that reads all kanban files and shows project progress visually. Hosted on Vercel for easy access from any device.

**How it works:**
1. `generate.js` reads `docs/kanban/*.md` files
2. Parses ticket data (ID, title, done/not done)
3. Injects it as JSON into `index.html`
4. Dashboard renders progress bars, ticket lists, and action buttons

**Key features:**
- Per-module progress (e.g., "META: 36/43 done — 84%")
- Overall project progress
- Clickable tickets that open a prompt composer with Build/Review/Test/Fix actions
- **"Build ALL" buttons** per module — one click launches Terminal and builds every open ticket sequentially
- **"Build next ticket"** buttons — copies a prompt for building one ticket at a time
- Auto-sync: board updates after every ticket completion
- **Live build status banner** — when `build-module.sh` is running, the dashboard shows a real-time progress banner with spinner, current ticket, progress bar, elapsed time, and ETA. Polls `.build-status.json` every 3 seconds. You can monitor from any device.

**The board does NOT add to agent context.** It's a human-facing tool. Agents interact with kanban `.md` files directly.

---

## Phase 5: The Build Cycle

This is the core of the system. For each ticket, one fresh Claude Code session handles the full lifecycle:

### Per Ticket (one fresh context window):

```
Build → Test → Fix → Update Kanban → Sync Board
```

1. **Build** — Read the kanban ticket. Read the module's source code. Implement the ticket completely following existing patterns.

2. **Test** — Run `npx tsc --noEmit` for type errors. Run `npx vitest run` for test failures.

3. **Fix** — Fix any type errors or test failures found in step 2. Iterate until clean.

4. **Update Kanban** — Edit the kanban `.md` file: change `⬜ TODO` to `✅ Done`, add notes describing what was built.

5. **Sync Board** — Commit and push the project. Then regenerate the dashboard:
   ```
   cd <dashboard-dir> && node generate.js && git add index.html && git commit -m "Regenerate dashboard: TICKET-ID done" && git push && npx vercel deploy --prod --yes
   ```

### Why one session per ticket:
- **Fresh context** — no stale state from previous tickets
- **Full awareness** — the build/test/fix loop stays in one context where the agent knows what it just built
- **Clean isolation** — if one ticket has issues, it doesn't poison the next

### Sequential execution:
The `build-module.sh` script handles this automatically. It reads the kanban, finds all open tickets, and launches a fresh `claude` session for each one. When one finishes, the next starts.

### Visual progress feedback:
While the build runs, the terminal shows:
- **Animated spinner** with elapsed time per ticket (e.g., `⠋ Building META-40... 3m 22s`)
- **Color-coded results** — green checkmarks for success, red crosses for failures
- **Progress bar** — `[██████░░░░░░] 33% — 1/3 tickets built`
- **ETA** — estimated time remaining based on average ticket build time
- **Per-ticket timing** — how long each ticket took to build
- **Build summary** — total time and per-ticket breakdown at the end

The script also writes a `.build-status.json` file that the dashboard polls every 3 seconds. When a build is running, the dashboard shows a live banner with the current ticket, progress bar, elapsed time, and ETA — so you can monitor from your phone or browser without watching the terminal.

---

## Phase 6: Module Review

**When:** After all tickets in a module are built.

**What happens:** `build-module.sh` automatically launches a final review session that:

1. Reads the original feature spec (the module's README in `src/features/<module>/README.md`)
2. Reads all source code that was built
3. Compares what was built against what the spec intended
4. For each area: reports what the spec says, what the code does, whether they match
5. If deviations exist: asks you whether each deviation is acceptable or needs fixing
6. If fixing is needed: creates a plan and executes it

**Why this matters:** Over the course of building 10-40 tickets, small deviations accumulate. The review catches drift before it becomes a problem.

---

## Phase 7: One-Click Automation

### The "Build ALL" button

On the dashboard, each module has a red "Build ALL" button. Clicking it:

1. Triggers the `converty-build://<module>` URL scheme
2. macOS opens `ConvertyBuild.app` (a tiny URL scheme handler)
3. ConvertyBuild.app opens Terminal and runs `build-module.sh <module>`
4. The script loops through every open ticket sequentially
5. Each ticket gets its own fresh Claude Code session
6. Board updates after each ticket
7. Final review session runs at the end

**Your role:** Click the button. Watch the progress banner on the dashboard (or the terminal spinner). The script handles everything automatically — no tool calls to approve (runs with `--dangerously-skip-permissions`). If a ticket fails, the script continues to the next one. Run it again to retry failed tickets.

### Setup

The `setup.sh` script handles all one-time setup:
- Creates the folder structure
- Copies template files
- Compiles and installs the ConvertyBuild.app URL handler
- Registers the URL scheme with macOS
- Initializes the git repo
- Deploys the initial dashboard

---

## Context Isolation Rules

These rules prevent context window bloat and ensure agents work efficiently:

1. **One kanban file per module.** Never combine modules into one file.
2. **Agents read only their module's kanban.** Never "read all kanbans."
3. **Module README files are for humans only.** Annotated as such. Agents don't load them unless explicitly told to.
4. **The PRD is read only at the start** — for grounding, not during builds.
5. **The dashboard is for humans.** Agents interact with `.md` files, not the HTML.
6. **Each ticket gets a fresh context window.** No carrying state between tickets.

---

## Quick Reference: Starting a New Project

```bash
# 1. Copy the template
cp -r self-building-board/template/ ~/Claude\ Code\ Projects/my-new-project/
cd ~/Claude\ Code\ Projects/my-new-project/

# 2. Run setup
bash setup.sh my-new-project

# 3. Start a Claude Code session and grill
# Use /grill-me to define modules and requirements

# 4. Generate kanban tickets from grill output
# Claude creates docs/kanban/<module>.md files

# 5. Generate the dashboard
node generate.js

# 6. Deploy
git add -A && git commit -m "Initial board" && git push && npx vercel deploy --prod --yes

# 7. Click "Build ALL" on the dashboard for each module
```

---

## File Structure

```
my-project/
├── CLAUDE.md                    # Agent instructions (auto-loaded)
├── docs/
│   ├── PRD.md                   # Product requirements (human + agent)
│   ├── kanban/                  # One file per module (agent-facing)
│   │   ├── meta.md
│   │   ├── rpt.md
│   │   └── ...
│   └── modules/                 # One README per module (human-facing)
│       ├── meta.md
│       ├── rpt.md
│       └── ...
├── src/                         # Source code
│   └── features/
│       ├── <module>/
│       │   ├── README.md        # Feature spec (agent reads during build)
│       │   └── ...
│       └── ...
├── index.html                   # Dashboard (generated)
├── generate.js                  # Dashboard generator
├── build-module.sh              # Sequential ticket builder
└── package.json
```
