# Self-Building Board

A complete methodology and toolkit for building large, production-grade software systems using Claude Code. Designed for non-developers who direct AI agents to build software.

You describe what you want. The system grills you, writes specs, generates tickets, and builds everything — automatically, with quality checks at every step.

---

## Table of Contents

1. [What Is This?](#what-is-this)
2. [The Full Flow — From Idea to Production](#the-full-flow--from-idea-to-production)
3. [Phase 1a: System Grill](#phase-1a-system-grill)
4. [Phase 1b: Module Grill](#phase-1b-module-grill)
5. [Phase 2: PRD Generation](#phase-2-prd-generation)
6. [Phase 3: Issue Generation](#phase-3-issue-generation)
7. [Phase 4: The Build — 5-Agent Pipeline](#phase-4-the-build--5-agent-pipeline)
8. [Phase 5: Module Review + Architecture Check](#phase-5-module-review--architecture-check)
9. [Phase 6: Dashboard](#phase-6-dashboard)
10. [Adding New Modules to a Running System](#adding-new-modules-to-a-running-system)
11. [Architecture Decisions — Full Q&A Record](#architecture-decisions--full-qa-record)
12. [Skills Reference](#skills-reference)
13. [Quick Start](#quick-start)

---

## What Is This?

The Self-Building Board is a system that turns a product idea into working software, built entirely by AI agents that you direct. It's designed for people who know what they want to build but don't write code themselves.

The system handles:

- **Grilling** — intensive interview sessions where Claude extracts every requirement from your head
- **Specification** — turning your requirements into formal documents (PRDs, module specs)
- **Ticket generation** — breaking specs into small, buildable tickets stored as GitHub Issues
- **Building** — a 5-agent pipeline that builds each ticket with built-in quality checks
- **Review** — automated module review and architecture health checks
- **Monitoring** — a visual dashboard where you track progress and trigger builds

Everything lives on GitHub. Issues for tickets. Actions for builds. Your Mac runs Claude using your Max subscription. The dashboard gives you a visual window into the entire process.

---

## The Full Flow — From Idea to Production

```
"I want to build an expense tracker"
        |
        v
Phase 1a: SYSTEM GRILL (you + Claude, ~30 min)
   Output: System PRD + Module Map + Interface Contracts + Module Build Order
        |
        v
Phase 1b: MODULE GRILL (you + Claude, ~20-40 min per module, in build order)
   Output: Module PRD + Module README
        |
        v
Phase 2: /write-a-prd (Claude formalizes the Module PRD)
   Output: Formal PRD document
        |
        v
Phase 3: /prd-to-issues (Claude generates GitHub Issues)
   Output: GitHub Issues with dependencies, labels, vertical slices
        |
        v
Phase 4: BUILD (GitHub Actions triggers, your Mac runs Claude)
   For each issue: Researcher -> Quality Architect -> Coder -> Reviewer <-> Coder -> QA <-> Coder
   Output: Working code, committed and pushed
        |
        v
Phase 5: MODULE REVIEW + ARCHITECTURE CHECK (automated)
   Output: Verification report, tech-debt issues if needed
        |
        v
Phase 6: DASHBOARD (your visual window)
   Monitor progress, trigger builds, inspect quality, track costs
```

Phases 1-3 require you in the chair (answering questions, approving breakdowns). Phase 4-6 are fully automated — click a button and walk away.

---

## Phase 1a: System Grill

**What it is:** A 30-60 minute session where Claude asks you big-picture questions about the system you want to build. The goal is to understand the full landscape before diving into details.

**Skill:** `/system-grill`

**What Claude asks about:**
- What is this system? What problem does it solve?
- Who uses it? What are their workflows?
- What are the major modules? (just names and one-line descriptions)
- What tech stack? What external services?
- What are the business constraints?

**What Claude does NOT ask about:** The internal details of any module. If you start explaining how campaign validation works, Claude stops you — "that's a Module Grill topic, we'll get there."

**Three outputs:**

### 1. Module Map
A list of every module in the system with a one-line description:
```
Modules:
  - Meta: Facebook/Meta campaign management
  - Creatives: Creative asset library and management
  - Reporting: Client-facing performance reports
  - Onboarding: New client setup flow
  - Billing: Invoice generation and tracking
```

### 2. Interface Contracts
The handshakes between modules — what data flows from A to B, in what format. This is the critical piece that allows modules to be built independently:
```
Creatives -> Meta:
  - Creatives exposes: getCreativesByClient(clientId)
  - Returns: [{id, imageUrl, headline, status}]
  - Meta calls this when setting up a new campaign

Meta -> Reporting:
  - Meta exposes: getCampaignMetrics(campaignId, dateRange)
  - Returns: {spend, impressions, clicks, conversions}
  - Reporting calls this to build client reports
```

These contracts are defined BEFORE any module is built. They're the "menu" that each module reads from and contributes to.

### 3. Module Build Order
Based on the Interface Contracts, which modules should be built first:
```
Layer 1: Database schema + Auth (everything needs these)
Layer 2: Creatives (Meta needs it, but it doesn't need Meta)
Layer 3: Meta, Google (need Creatives, independent of each other -> parallel)
Layer 4: Reporting (needs Meta + Google data)
Layer 5: Onboarding (needs everything to wire a new client through)
```

Modules in the same layer can be built in parallel. Layers are built sequentially.

---

## Phase 1b: Module Grill

**What it is:** A 20-40 minute deep-dive into ONE module. This is where you describe every business rule, edge case, and workflow for that specific module.

**Skill:** `/module-grill`

**When to run it:** Just before you're ready to build that module. Not months in advance — the closer to build time, the fresher the context.

**What Claude already knows going in:**
- The System PRD (from Phase 1a)
- The Interface Contracts (so it knows what this module must expose and consume)
- What other modules have already been built (if any)

**What Claude asks about:**
- Every feature in detail
- Business rules and validation logic
- Edge cases ("what happens when X?")
- Error handling ("what if the API is down?")
- User workflows step by step
- Data models and relationships

**Output:** Module PRD + Module README

The Module README goes into `docs/modules/<module>.md` and preserves the full context of the grill — every decision, every edge case, every "why." This file is for human reference. Agents read the tickets, not this file (except the Researcher agent, which uses it to produce briefings).

---

## Phase 2: PRD Generation

**What it is:** Claude takes the raw Module Grill output and formalizes it into a structured PRD (Product Requirements Document).

**Skill:** `/write-a-prd`

**Output:** A formal PRD document stored as a GitHub Issue on the project repo. This becomes the "parent" issue that all tickets reference back to.

---

## Phase 3: Issue Generation

**What it is:** The PRD is broken down into independently-buildable GitHub Issues using vertical slices (tracer bullets).

**Skill:** `/prd-to-issues`

### Vertical Slices, Not Horizontal Layers

Each issue is a thin cut through ALL layers of the system, not a single-layer task:

```
BAD (horizontal):                    GOOD (vertical):
  Issue 1: Build all DB tables         Issue 1: Register + create first expense
  Issue 2: Build all API routes            (DB + API + test, end-to-end)
  Issue 3: Build all tests             Issue 2: Login + auth middleware
                                           (DB + API + middleware + test)
```

A vertical slice is demoable on its own. You can verify it works. Horizontal slices produce nothing usable until ALL of them are done.

### Dependency Mapping

The skill automatically identifies which issues block which others and records it in each issue body:

```markdown
## Blocked by
- Blocked by #12 (database schema must exist)
- Blocked by #14 (auth middleware required)
```

Or: `None - can start immediately` for issues with no dependencies.

### Layer Computation

At build time, the system reads all `## Blocked by` sections and computes execution layers:

```
Layer 1: [#2]           <- no dependencies, starts first
Layer 2: [#3, #5, #6]   <- all depend only on Layer 1, run in PARALLEL
Layer 3: [#4, #7]       <- depend on Layer 2 items, run in PARALLEL
```

Issues within the same layer run in parallel. Layers run sequentially. A 15-issue module that would take 75 minutes sequentially might finish in 25 minutes with 3 parallel layers.

### Two-Gate Sizing Rule

Every issue must pass two gates:

1. **Input gate (60K tokens):** The total context an agent needs to read (module README + existing source files + ticket) must stay under 60K tokens. In practice: ~8-12 existing source files of context.

2. **Output gate (3 files max):** A single issue should produce or modify no more than 3 files of code changes. If it needs to touch more, split it.

If an issue violates either gate, the skill splits it further.

### Module Labels

Each issue gets a `module:<name>` label (e.g., `module:meta`, `module:reports`) for organization. An `escalated` label (red) is created for the build pipeline to use later.

### Issue Body Format

```markdown
## Parent PRD
#1

## What to build
End-to-end description of this vertical slice.

## Why
Business reason this slice matters.

## Acceptance criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by
- Blocked by #12 (reason)

## User stories addressed
- User story 3
- User story 7
```

---

## Phase 4: The Build — 5-Agent Pipeline

This is the core of the system. For each GitHub Issue, a pipeline of 5 specialized agents builds the code with quality checks at every step.

### The Pipeline

```
RESEARCHER (Sonnet)
    |
    v
QUALITY ARCHITECT (Sonnet)
    |
    v
CODER (Opus)  <----+
    |               |
    v               |
REVIEWER (Sonnet)   | (max 3 cycles, then escalate)
    |  fail --------+
    |  pass
    v
QA (Sonnet)  -------+
    |  fail         |
    |               v
    |          back to CODER -> REVIEWER loop (max 3 more cycles)
    |  pass
    v
DONE - issue closed
```

### Agent Roles in Detail

#### 1. Researcher (Sonnet)

The tech lead. Its job is to read and distill. It's the ONLY agent that reads the codebase directly.

**Reads:**
- The GitHub Issue (ticket)
- The module README (`docs/modules/<module>.md`)
- Existing source files relevant to this ticket
- The Interface Contracts (to understand cross-module boundaries)

**Produces:** A distilled tech briefing — a focused document that tells the Coder exactly what it needs to know, without the noise of reading the entire codebase.

**Why Sonnet:** This is synthesis work, not code generation. Sonnet is fast, cheap, and has a 200K context window — plenty of room for reading source files.

#### 2. Quality Architect (Sonnet)

Chained AFTER the Researcher (not parallel). Reads the Researcher's briefing and the ticket.

**Produces:**
- TDD test specifications (what tests to write, what they should verify)
- Quality criteria (performance requirements, edge cases to handle)
- Efficiency standards ("this should be O(n), not O(n^2)")
- "Best way to do it" guidelines

**Why it exists:** Quality is front-loaded. The test specs and quality criteria are defined BEFORE the Coder starts. Prevention over detection.

**Why Sonnet:** Synthesis work on pre-digested input. Doesn't need Opus-level reasoning.

#### 3. Coder (Opus)

The builder. The ONLY agent that uses Opus (the most capable and expensive model).

**Receives:** Both the Researcher's briefing and the Quality Architect's specs.

**Does NOT:** Read any codebase files directly. Works entirely from the briefings. This keeps its context focused on building, not reading.

**Workflow (TDD — mandatory):**
1. Read the Quality Architect's test specs
2. Write failing tests that match those specs
3. Run the tests — verify they FAIL (red)
4. Write the minimum code to make tests pass (green)
5. Refactor if needed
6. Run tests again — verify they PASS

**Stays alive for retries:** Within a single ticket, the Coder session persists through the Reviewer feedback loop. It doesn't start fresh each retry — it remembers what it built and what feedback it received. Fresh sessions only across different tickets.

#### 4. Reviewer (Sonnet)

Correctness checker. Compares the code against the ticket spec and the Quality Architect's criteria.

**Checks:**
- Does the code do what the ticket says?
- Do the tests cover the acceptance criteria?
- Does it follow the spec?

**Does NOT:** Judge code style, suggest refactors, or check architecture. That's the QA agent's job.

**On pass:** Moves to QA.
**On fail:** Sends specific feedback back to the SAME Coder session. The Coder fixes and resubmits. Max 3 cycles.

**Has NO authority to auto-fix.** It only provides feedback. The Coder does the fixing.

#### 5. QA (Sonnet)

The final gatekeeper. Runs ONCE after the Reviewer approves.

**Does:**
- Runs all tests
- Hunts edge cases the Coder might have missed
- Checks efficiency ("is this O(n^2) when it could be O(n)?")
- Asks "is this the BEST way to do it? Could it be simpler, faster, leaner?"
- Verifies the code fits well with the broader codebase

**On pass:** Issue is closed. Code is committed and pushed.
**On fail:** Sends feedback back to the Coder -> Reviewer loop. Max 3 more cycles, then escalate.

### Escalation

If the Reviewer or QA loop hits 3 failed cycles, the system:

1. Labels the GitHub Issue as `escalated` (red)
2. Writes an escalation comment on the issue with: what was attempted, what failed, suggested next steps
3. Saves intermediate files (research briefing, QA spec, code attempts) as GitHub Actions artifacts for debugging
4. Continues to the next issue — the build doesn't stop

Escalated issues appear highlighted in orange on the dashboard. You can inspect them, understand what went wrong, and either fix manually or re-run with adjusted instructions.

### How It Runs: GitHub Actions + Self-Hosted Mac Runner

The build pipeline runs as a GitHub Actions workflow:

- **Trigger:** Click "Build Module" on the dashboard, or manually trigger from GitHub Actions tab
- **Where Claude runs:** On YOUR Mac, using your Claude Max subscription ($200/month). Zero extra API cost.
- **How:** Your Mac is registered as a GitHub Actions "self-hosted runner." GitHub sends the workflow to your Mac. Your Mac runs Claude Code locally. Results flow back to GitHub.
- **Your Mac must be on during builds.** But you don't need to watch — the dashboard shows live progress.

**Parallelism:** Issues within the same dependency layer run in parallel. Layers run sequentially. The workflow computes layers automatically from the `## Blocked by` sections in each issue.

### Agent Handoff: File-Based on Shared Workspace

Each agent saves its output as a file. The next agent reads that file:

```
Step 1: Researcher -> saves research-briefing.md
Step 2: Quality Architect -> reads briefing, saves qa-spec.md
Step 3: Coder -> reads both files, writes actual code
Step 4: Reviewer -> reads code + ticket spec, pass/fail
Step 5: QA -> reads everything, final audit
```

These intermediate files are saved as GitHub Actions artifacts. If something goes wrong, you (or Claude) can download them and see exactly what each agent was thinking. Built-in debugging for free.

---

## Phase 5: Module Review + Architecture Check

After ALL issues in a module are built, two automated checks run:

### Module Review

Compares what was built against what the spec intended:
- Reads the original Module README (the spec)
- Reads all source code that was built
- For each area: what the spec says vs. what the code does
- Reports deviations

### Architecture Check (`/improve-codebase-architecture`)

Looks at the code that was just built and asks:
- Any duplicated logic across files?
- Inconsistent patterns?
- Missing abstractions?
- Code that could be simpler?

If it finds issues, it creates new GitHub Issues tagged `tech-debt` for the next build cycle.

---

## Phase 6: Dashboard

Your visual window into the entire system. A single-page HTML dashboard deployed on Vercel. Reads all data from GitHub API.

### What You See

1. **Per-module progress bars** — "Meta: 36/43 done — 84%"
2. **Overall project progress** — across all modules
3. **Live build status** — "Module META is building: ticket #42, 3/15, started 12 min ago"
4. **Escalated tickets** — highlighted orange with details on what went wrong
5. **One-click build trigger** — button per module that starts the GitHub Actions workflow
6. **Recent activity feed** — "Last build: 2 hours ago. 14 succeeded, 1 escalated"
7. **Cost tracker** — estimated token usage and dollar cost per module build
8. **Improvement suggestions** — findings from the architecture check
9. **Key files reference panel** — links to module READMEs, database schema, architecture docs, PRD
10. **Per-ticket quality badge** — each completed ticket shows: QA passed, Tests passed, Review passed

### What You Don't See

The dashboard is for humans. Agents never interact with the dashboard. They read GitHub Issues and write code. The dashboard reads from GitHub API and displays it visually.

---

## Adding New Modules to a Running System

When your system is already built and running, and you want to add a new module:

### Step 1: Mini System Grill (~15 min)

Three questions:
1. What does the new module need FROM existing modules? (check the Interface Contracts — it might already be available)
2. What do existing modules need FROM the new module? (new contracts to define)
3. Do existing modules need any changes? (small tickets on existing modules)

### Step 2: Categorize the Work

- **Bucket A: "Just use it"** — existing interfaces the new module consumes as-is. No work needed on existing modules.
- **Bucket B: "Small additions"** — existing modules need minor extensions (new endpoint, new field). Small issues on existing modules.
- **Bucket C: "New module internals"** — the new module's own logic. Full Module Grill -> /prd-to-issues -> build.

### Step 3: Build Order

1. Build Bucket B tickets first (small additions to existing modules)
2. Then build Bucket C (new module) — it can now use everything

The existing system's Interface Contracts act as a "menu." The new module shops from the menu. Only if something isn't on the menu do you add to it.

---

## Architecture Decisions — Full Q&A Record

This section documents every design decision made during the grill sessions on April 5, 2026. Each entry shows the question discussed, the options considered, and the final decision with reasoning.

### Decision 1: Agent Pipeline Design

**Question:** How many agents should handle each ticket, and what should each one do?

**Options considered:**
- Single agent does everything (simple but no quality checks)
- 3 agents: Researcher, Coder, Reviewer (misses QA)
- 5 agents: Researcher, Quality Architect, Coder, Reviewer, QA (comprehensive)

**Decision:** 5-agent pipeline.

**Reasoning:** Quality needs to be front-loaded (Researcher + Quality Architect define standards BEFORE the Coder starts) AND back-loaded (Reviewer checks correctness, QA audits quality). The Researcher ensures the Coder gets distilled context instead of reading the raw codebase. The Quality Architect ensures TDD specs exist before coding begins. The separation between Reviewer (correctness only) and QA (comprehensive audit) prevents the review step from becoming a bottleneck — it stays fast and focused.

### Decision 2: Which Models for Which Agents

**Question:** Should all agents use Opus, or should we optimize?

**Decision:** Only the Coder uses Opus. All others use Sonnet.

**Reasoning:** The Researcher, Quality Architect, Reviewer, and QA are doing synthesis, analysis, and comparison work — Sonnet handles this excellently and is much cheaper/faster. The Coder is the only agent that needs Opus-level reasoning for writing complex, correct code. This keeps costs manageable while maintaining code quality.

### Decision 3: Coder Session Persistence

**Question:** Should the Coder get a fresh session for each retry, or stay alive?

**Decision:** Coder stays alive for retries within one ticket. Fresh session only for new tickets.

**Reasoning:** If the Reviewer says "fix the error handling in line 42," the Coder needs to remember what it built. Starting fresh would lose that context and force re-reading all briefings. Keeping the session alive allows focused fixes.

### Decision 4: Reviewer vs QA Separation

**Question:** Why not have one review agent that checks both correctness and quality?

**Decision:** Separate agents for correctness (Reviewer) and quality (QA).

**Reasoning:** The Reviewer runs in a tight loop with the Coder (up to 3 cycles). If it also checked efficiency, architecture, and best practices, each cycle would be slow and expensive. By keeping the Reviewer focused on "does it match the spec?", the loop stays fast. QA runs ONCE after the Reviewer approves, doing the deep audit.

### Decision 5: Escalation Mechanism

**Question:** What happens when the Coder can't fix something after multiple attempts?

**Decision:** After 3 failed Reviewer cycles OR 3 failed QA cycles, escalate. Label the issue `escalated`, write a detailed comment, save artifacts, continue to the next issue.

**Reasoning:** Infinite retry loops waste time and money. 3 cycles is enough for most fixable issues. Anything beyond that likely needs human judgment (architectural decision, ambiguous spec, external dependency issue). The build continues to the next issue so one stuck ticket doesn't block everything.

### Decision 6: Ticket Storage — GitHub Issues over Kanban Files

**Question:** Should tickets live in local markdown kanban files or on GitHub Issues?

**Options considered:**
- Kanban `.md` files (current approach — simple, local, no API dependency)
- GitHub Issues (cloud-native, isolated, rich formatting)

**Decision:** GitHub Issues.

**Reasoning:** Kanban files caused the biggest problem in practice — agents "accidentally" reading the entire board and bloating their context. With GitHub Issues, each ticket is naturally isolated (`gh issue view 42` returns exactly one issue). Additional benefits: rich markdown body instead of cramming WHAT+SPEC+WHY into a table cell, labels for organization, cloud-native access from anywhere, `/prd-to-issues` works natively without format conversion, and done = close the issue (no more editing markdown to swap emojis).

**Downsides accepted:** Requires internet (but builds already need internet for git push). Slightly slower per-ticket fetch (~0.5s vs instant file read — negligible when each ticket takes minutes to build). GitHub dependency (already exists for code storage).

### Decision 7: Ticket Sizing — Two-Gate Rule

**Question:** How big should a single ticket/issue be?

**Options considered:**
- Size by file count (fuzzy — files vary in size)
- Size by Researcher's read capacity only
- Two-gate rule: input capacity AND output scope

**Decision:** Two-gate rule.

**Reasoning:** Sizing only by what the Researcher can read misses the Coder's output quality. A ticket that requires reading 8 files but modifying 10 files is readable for the Researcher but too scattered for the Coder to implement well in one shot. The output gate (max 3 files modified) ensures each ticket is focused. If a ticket violates either gate, split it.

### Decision 8: Dependency Layers for Parallel Execution

**Question:** Should tickets be built sequentially or in parallel?

**Decision:** Parallel within dependency layers, sequential across layers.

**Reasoning:** The user correctly pointed out that blindly running everything sequentially is wasteful. Many issues are independent and can run simultaneously. The `/prd-to-issues` skill already outputs `## Blocked by` relationships. At build time, the system computes layers from this dependency graph and runs all same-layer issues in parallel. A 15-issue module with 3 layers finishes in ~25 minutes instead of ~75 minutes.

### Decision 9: /prd-to-issues Integration

**Question:** Should we use `/prd-to-issues` as-is, build a custom ticket generator, or adapt the skill?

**Decision:** Use `/prd-to-issues` and amend the skill with three additions.

**Reasoning:** The skill already handles the hard work — decomposition into vertical slices, dependency mapping, blocking relationships. Three gaps were identified and fixed directly in the skill file (`~/.claude/skills/prd-to-issues/SKILL.md`):
1. Added `## Why` section to the issue template (business reason for agents)
2. Added Step 6 for module label creation and application
3. Added `<sizing-rules>` with the two-gate sizing rule

Verified with a live test on a temporary GitHub repo (`alonconvert/sbb-test-run`). Dependencies parse correctly from issue bodies. Layer computation works. All gaps closed at the source.

### Decision 10: Build Orchestration — GitHub Actions over Local Script

**Question:** Should `build-module.sh` (local Mac script) remain the orchestrator, or should we move to GitHub Actions?

**Decision:** GitHub Actions with self-hosted Mac runner.

**Reasoning:** With tickets on GitHub Issues and code on GitHub, the orchestrator should also be on GitHub. This is how real development teams work. The dashboard button triggers a GitHub Actions workflow. But since Claude Max ($200/month subscription) only works on the local Mac (not on GitHub's servers where API keys would cost $5-15 per ticket), the Mac is registered as a self-hosted GitHub Actions runner. GitHub sends the workflow to the Mac. The Mac runs Claude locally. Results flow back to GitHub. Best of both worlds: cloud-triggered, zero extra cost.

### Decision 11: Self-Hosted Runner over API

**Question:** How does Claude run inside GitHub Actions?

**Options considered:**
- Anthropic API key on GitHub's servers ($5-15 per ticket, potentially thousands per project)
- Self-hosted runner on Mac (uses Max subscription, zero extra cost)
- Stay fully local with no GitHub Actions (simplest but loses dashboard triggers)

**Decision:** Self-hosted Mac runner.

**Reasoning:** API costs are prohibitive for large projects. A 40-ticket module with 5 agents per ticket could cost $200-600 in API fees — on top of the $200/month Max subscription. The self-hosted runner gives all the benefits of GitHub Actions (dashboard triggers, cloud orchestration, workflow YAML, artifacts) while running Claude on the Mac where the Max subscription provides unlimited usage.

### Decision 12: Cascading Grill Sessions

**Question:** How do you spec out a massive system with dozens of modules without one marathon grill session?

**Decision:** Cascading grills — zoom in progressively.

**Reasoning:** One massive grill session produces shallow specs. Detailed grills for every module upfront wastes time on modules that won't be built for weeks. The cascading approach: System Grill first (big picture, ~30 min), then Module Grill per module just before building it (~20-40 min each). Each Module Grill has the System PRD and Interface Contracts as context, so it knows the boundaries. Modules that aren't ready yet don't block modules that are.

### Decision 13: Interface Contracts

**Question:** How do you build modules that depend on each other when grilling them separately?

**Decision:** Define Interface Contracts during the System Grill, before any module is built.

**Reasoning:** The Interface Contracts specify the handshakes between modules — what data flows from A to B, in what format. This allows each Module Grill to know its boundaries: "this is what you receive, this is what you provide." Each module is then built against those contracts. This is standard practice in large software companies — teams agree on APIs before building independently.

### Decision 14: /improve-codebase-architecture Placement

**Question:** When should the architecture health check run?

**Options considered:**
- After every module completes (catches drift early)
- As a manual periodic health check (less overhead but drift accumulates)
- Inside the QA agent per ticket (misses cross-ticket patterns)

**Decision:** Automatically after each module review completes.

**Reasoning:** The module review already checks "did we build what the spec said?" The architecture check adds "did the code stay clean while doing it?" Running per-module catches drift after 15 tickets (manageable) instead of after 60 (expensive to fix). Running per-ticket would miss cross-ticket patterns.

### Decision 15: Dashboard Design Philosophy

**Question:** How should the dashboard change with all the new architecture?

**Decision:** Enhance the current dashboard, don't redesign. Add: cost tracker, quality badges, escalation alerts, build trigger buttons, key files panel, improvement suggestions.

**Reasoning:** The current dashboard's look and feel works well. The user doesn't care where data comes from (local files vs GitHub API) — they care about what they see. Data source changes under the hood. New panels add visibility into cost, quality, and escalations without changing the core experience.

### Decision 16: Standard Practices First

**Guiding principle established during the grill:** Always use industry-standard developer workflows (GitHub Actions, GitHub Issues, standard CI/CD patterns) whenever possible. Only deviate from standard where the user's specific needs require it — primarily: a visual dashboard (because the user doesn't read raw GitHub UI), and guided workflows (because the user isn't a developer and needs the system to explain working methods).

This principle applies to all future architecture decisions.

---

## Skills Reference

| Skill | Phase | What it does |
|-------|-------|-------------|
| `/system-grill` | 1a | High-level system interview. Outputs Module Map, Interface Contracts, Build Order |
| `/module-grill` | 1b | Deep-dive module interview. Reads Interface Contracts as constraints. Outputs Module PRD |
| `/write-a-prd` | 2 | Formalizes grill output into a structured PRD |
| `/prd-to-issues` | 3 | Breaks PRD into vertical-slice GitHub Issues with dependencies and labels |
| `/tdd` | 4 (embedded) | Not run as a separate step. Baked into the Coder's workflow via Quality Architect specs |
| `/improve-codebase-architecture` | 5 | Runs after module review. Finds architectural issues, creates tech-debt tickets |
| `/new-project` | Setup | One-command project initialization: repo, labels, dashboard, runner setup |

---

## Quick Start

```bash
# 1. Start a new project
#    (In Claude Code, run:)
/new-project

# 2. System Grill — describe your big picture
/system-grill

# 3. Module Grill — deep-dive into the first module
/module-grill

# 4. Generate the PRD
/write-a-prd

# 5. Generate tickets
/prd-to-issues

# 6. Click "Build" on the dashboard — walk away
#    (Or trigger from GitHub Actions tab)

# 7. Come back to a built module. Review the dashboard.
#    Repeat from step 3 for the next module.
```

---

## File Structure

```
my-project/
|-- .github/
|   `-- workflows/
|       `-- build-module.yml          # GitHub Actions pipeline
|-- docs/
|   |-- modules/                      # Module READMEs (human-facing, one per module)
|   |   |-- meta.md
|   |   |-- reports.md
|   |   `-- ...
|   `-- system/
|       |-- system-prd.md             # System-level PRD
|       |-- interface-contracts.md    # Cross-module contracts
|       `-- build-order.md            # Module dependency order
|-- src/                              # Source code
|   `-- features/
|       |-- <module>/
|       |   |-- README.md             # Feature spec (agent reads during build)
|       |   `-- ...
|       `-- ...
|-- dashboard/
|   |-- index.html                    # Dashboard (deployed on Vercel)
|   `-- generate.js                   # Dashboard generator (reads GitHub API)
|-- CLAUDE.md                         # Agent instructions (auto-loaded)
`-- package.json
```

---

## Design Principles

1. **Standard practices first.** Use industry-standard workflows (GitHub Issues, Actions, CI/CD). Only deviate for non-developer visual/guidance needs.

2. **Quality is front-loaded.** The Researcher and Quality Architect define standards BEFORE the Coder starts. Prevention over detection.

3. **Context isolation is sacred.** No agent reads more than it needs. One issue at a time. Briefings distill context. No bloat.

4. **Vertical slices over horizontal layers.** Each ticket delivers a complete, verifiable path through the entire stack.

5. **Escalate, don't loop forever.** 3 retries max, then escalate and move on. Human judgment for the hard problems.

6. **Everything in the cloud.** Tickets, code, orchestration, dashboard — all on GitHub/Vercel. The Mac is just the compute engine.

7. **The dashboard is for humans.** Agents never touch it. It's your window, not theirs.
