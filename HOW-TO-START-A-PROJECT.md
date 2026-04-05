# How to Start a New Project — Step by Step

This is a plain English guide for you (Alon) to follow every time you want to build a new project using the Claude Project System. No technical jargon. Just actions.

---

## Before You Start

You need one thing: **a clear idea of what you want to build.** It doesn't need to be detailed — that's what the grill session is for. Just know the general direction. For example: "I want a system that automatically generates weekly video reports for my clients" or "I want a referral program that tracks who brought in new clients."

---

## Step 1: Create the Project Folder

Open Claude Code and tell it:

> "Create a new project called [your project name] using the Claude Project System template."

Claude will:
- Copy the template files from `claude-project-system/template/` into a new folder
- Run the setup script that creates all the necessary folders and installs the dashboard button system
- Initialize a git repository

**What you'll have after this step:** An empty project skeleton with all the tools ready to go.

---

## Step 2: The Grill Session

This is the most important step. This is where you and Claude sit down and figure out exactly what the system needs to do.

Open Claude Code in your new project folder and say:

> "I want to build [describe your idea]. Grill me on it — ask me everything you need to know to fully understand what I want."

Claude will ask you questions. Answer them honestly and completely. Think about:

- **Who is this for?** (You? Your clients? Your team?)
- **What does it actually do?** (Not features — outcomes. What changes in your day when this exists?)
- **What external services does it connect to?** (Google Ads? Meta? WhatsApp? Supabase?)
- **What are the rules?** (Business logic, constraints, things that must always be true)
- **What does it NOT do?** (Scope boundaries — equally important)

The grill session might take 20-30 minutes. That's fine. Every minute spent here saves hours of rework later.

**What you'll have after this step:** A deep, shared understanding of the system between you and Claude.

---

## Step 3: Write the PRD

After the grill, tell Claude:

> "Now write the PRD based on everything we discussed. Use the PRD template."

Claude will create `docs/PRD.md` — a structured document that captures the vision, modules, integrations, and scope. Read it carefully. This is your project's constitution.

**If something is wrong or missing, say so now.** It's 100x easier to fix a PRD than to fix code.

**What you'll have after this step:** A single document that defines what the system is.

---

## Step 4: Define the Modules

From the PRD, Claude will identify the natural modules — the big building blocks of your system. For example, Converty OS had: Meta Image Generator, Onboarding, Reports, Landing Pages, Referrals.

Tell Claude:

> "Break this into modules. For each module, create a detailed README in docs/modules/ and a kanban file in docs/kanban/."

Claude will create two things per module:

### The Module README (`docs/modules/<module>.md`)
This is your personal reference document. It captures everything from the grill session about this module — the decisions, the reasoning, the edge cases, the "why." 

**You will never need to read this during a build.** But if months from now you wonder "why did we build it this way?" — this is where you'll find the answer.

### The Kanban File (`docs/kanban/<module>.md`)
This is the operational file — the list of tickets that agents will actually build. Each ticket is a specific, buildable unit of work with an ID, title, and status.

**What you'll have after this step:** A complete breakdown of every piece of work that needs to happen, organized by module.

---

## Step 5: Set Up the Module Mappings

Tell Claude:

> "Fill in modules.conf with the module mappings for this project."

This is a simple configuration file that tells the build system which folder corresponds to which module. Claude handles this — you just need to approve it.

**What you'll have after this step:** The build system knows where each module's code lives.

---

## Step 6: Generate the Dashboard

Tell Claude:

> "Generate the dashboard and deploy it."

Claude will:
1. Run `node generate.js` to read all kanban files and create the dashboard
2. Customize the `index.html` with your project's modules, phases, and action buttons
3. Deploy it to Vercel

**What you'll have after this step:** A live dashboard at a URL you can open on your phone, tablet, or any browser. It shows every module, every ticket, and overall progress.

---

## Step 7: Review the Dashboard

Open the dashboard URL. You should see:

- **Progress bars** for each module (all at 0% since nothing is built yet)
- **Ticket lists** showing every piece of work
- **"Build next ticket" buttons** — for building one ticket at a time
- **"Build ALL" buttons** (red) — for building an entire module end-to-end
- **A "Sync Now" button** — for manually refreshing the board

Take a moment to look at the full scope. This is your project. Every ticket, every module, laid out visually. If something looks wrong — too many tickets, missing module, wrong priority order — now is the time to adjust.

---

## Step 8: Start Building

Now the fun part. You have two options:

### Option A: Build One Ticket at a Time
Click on any ticket on the dashboard. A prompt composer appears with four actions:
- **Build** — write the code
- **Review** — audit the code
- **Test** — write tests
- **Fix** — find and fix bugs, then update the board

Click the action you want. It copies a prompt. Open a new Claude Code window, paste it, and let Claude work. When the Fix action completes, the board automatically updates.

### Option B: Build an Entire Module at Once (Recommended)
Click the red **"Build ALL"** button on any module. This:
1. Opens a Terminal window automatically
2. Finds all open tickets in that module
3. For each ticket, opens a fresh Claude Code session
4. Each session builds the ticket, tests it, fixes issues, and updates the board
5. When one ticket finishes, the next one starts automatically
6. After all tickets: a final review session compares what was built against the original spec

**What you'll see while it runs:**

In the **Terminal**: a spinner with elapsed time for each ticket, color-coded results, a progress bar, and an ETA for how long the remaining tickets will take. After each ticket, you'll see a summary of what was built and how long it took.

On the **Dashboard**: a live status banner appears at the top of the page showing the current ticket being built, a progress bar, elapsed time, and estimated time remaining. This updates every 3 seconds — so you can monitor from your phone, iPad, or any browser without keeping the Terminal visible.

**Your role during this:** Watch the progress. The build runs fully autonomously — no tool calls to approve. If a ticket fails, the script logs the error and moves on to the next one. You can re-run the script to retry any failed tickets (it skips already-completed ones).

---

## Step 9: Module Review

After all tickets in a module are built, the system automatically runs a review session. This session:

1. Reads the original feature spec
2. Reads all the code that was built
3. Compares them point by point
4. Reports any deviations

If there are deviations, Claude will ask you: "Is this acceptable, or should we fix it?" You decide.

If you need to dig deeper into why something was built a certain way, this is when you pull up the Module README (`docs/modules/<module>.md`) — your human reference document with all the context from the grill session.

---

## Step 10: Repeat for Each Module

Go back to the dashboard. Pick the next module. Click "Build ALL." Repeat until the project is complete.

The dashboard updates in real-time as each ticket is completed. You can always see:
- How far along each module is
- What's been built
- What's remaining
- Overall project completion percentage

---

## The Daily Workflow (Once a Project is In Progress)

1. **Open the dashboard** — check where things stand
2. **Pick a module** — click "Build ALL" or "Build next ticket"
3. **Supervise** — watch Claude work, approve actions
4. **Check the board** — confirm tickets are marked done and progress updated
5. **Repeat**

That's it. The system handles everything else — context isolation, board syncing, sequential execution, fresh sessions, and final reviews.

---

## If Something Goes Wrong

### "The board didn't update"
Open Claude Code in the dashboard project folder and say: "Regenerate the board and deploy it."

### "A ticket was built wrong"
Click the ticket on the dashboard and use the "Fix" action. It will re-examine the code and fix issues.

### "The build seems stuck — is it still running?"
Look at the dashboard — if the live status banner is showing with a spinning indicator and updating elapsed time, it's still working. Each ticket can take 5-20 minutes. If the terminal shows a spinner with increasing time, it's running. If both are frozen for more than 30 minutes, the session may have hit an issue — close the terminal and run `bash build-module.sh <module>` again to continue from where it left off.

### "Some tickets failed during Build ALL"
The summary at the end shows which tickets failed. Just run `bash build-module.sh <module>` again — it reads the kanban fresh and only builds tickets still marked as open.

### "I want to change what a module does"
Update the Module README and the kanban tickets. Then regenerate the dashboard. The system adapts.

### "I lost track of what was decided during the grill"
Open `docs/modules/<module>.md` — that's exactly what it's there for.

### "Context seems bloated / Claude is slow"
Make sure agents are only reading one kanban file at a time, not all of them. Check that Module READMEs aren't being loaded unnecessarily.

---

## Summary: The Full Lifecycle

```
1. Create project from template
2. Grill session — deep interview about what to build
3. Write PRD — the project constitution
4. Create modules — README (for you) + kanban tickets (for agents)
5. Generate dashboard — visual command center
6. Build — one click per module, fresh session per ticket
7. Review — verify against spec after each module
8. Repeat until done
```

Every phase produces a concrete artifact. Nothing is just a conversation. Everything is tracked, documented, and visible on the dashboard.
