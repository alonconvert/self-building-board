#!/bin/bash
# build-module.sh — Build all open tickets in a module sequentially.
# Each ticket gets its own fresh Claude Code session.
# Usage: bash build-module.sh <module>
#   e.g.: bash build-module.sh meta
#
# Set PROJECT_DIR env var to point to your project, or it defaults to ../project

set -e

MODULE="${1:?Usage: bash build-module.sh <module>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR"

# Project root: set via env var, or default to ../project relative to this script
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_ROOT="$(cd "$PROJECT_DIR" && pwd)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../project" && pwd)"
fi

# Module-to-feature-dir mapping (compatible with bash 3.2)
# Customize this for your project — map module keys to src/features/ directory names
FEATURE=""
MODULES_FILE="$SCRIPT_DIR/modules.conf"
if [ -f "$MODULES_FILE" ]; then
  FEATURE=$(grep "^${MODULE}=" "$MODULES_FILE" | cut -d'=' -f2)
else
  echo "WARNING: modules.conf not found. Feature spec lookup disabled."
fi

KANBAN_FILE="$PROJECT_ROOT/docs/kanban/${MODULE}.md"
SPEC_PATH=""
if [ -n "$FEATURE" ]; then
  SPEC_PATH="src/features/${FEATURE}/README.md"
fi

if [ ! -f "$KANBAN_FILE" ]; then
  echo "ERROR: Kanban file not found: $KANBAN_FILE"
  exit 1
fi

# Extract open tickets: lines containing the unchecked box emoji
TICKET_LINES=()
while IFS= read -r line; do
  TICKET_LINES+=("$line")
done < <(grep -E '^\|.*⬜' "$KANBAN_FILE")

if [ ${#TICKET_LINES[@]} -eq 0 ]; then
  echo "No open tickets in ${MODULE} module. Nothing to build!"
  exit 0
fi

# Parse ticket IDs and titles
TICKET_IDS=()
TICKET_TITLES=()
for line in "${TICKET_LINES[@]}"; do
  id=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  title=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
  TICKET_IDS+=("$id")
  TICKET_TITLES+=("$title")
done

TOTAL=${#TICKET_IDS[@]}
MODULE_UPPER="$(echo "$MODULE" | tr '[:lower:]' '[:upper:]')"
echo ""
echo "=========================================="
echo "  BUILD MODULE: ${MODULE_UPPER}"
echo "  ${TOTAL} open tickets to build"
echo "=========================================="
echo ""

for i in "${!TICKET_IDS[@]}"; do
  TID="${TICKET_IDS[$i]}"
  TTITLE="${TICKET_TITLES[$i]}"
  NUM=$((i + 1))

  echo "----------------------------------------"
  echo "  [$NUM/$TOTAL] ${TID}: ${TTITLE}"
  echo "----------------------------------------"
  echo ""

  SPEC_INSTRUCTION=""
  if [ -n "$SPEC_PATH" ]; then
    SPEC_INSTRUCTION="Read the feature spec at ${SPEC_PATH}. "
  fi

  PROMPT="You are building ticket ${TID} for the ${MODULE_UPPER} module. ${SPEC_INSTRUCTION}Read docs/kanban/${MODULE}.md to understand the ticket: ${TID} — ${TTITLE}. Implement it completely following existing code patterns. After building: run npx tsc --noEmit and fix any type errors. Run npx vitest run for related tests and fix any failures. Then update docs/kanban/${MODULE}.md to mark ${TID} as done with notes on what was built. Commit and push. Then cd to ${DASHBOARD_DIR} and run: node generate.js && git add index.html && git commit -m 'Regenerate dashboard: ${TID} done' && git push && npx vercel deploy --prod --yes. Tell me which ticket you completed and summarize what was built."

  cd "$PROJECT_ROOT"
  claude "$PROMPT"

  echo ""
  echo "  [${NUM}/${TOTAL}] ${TID} session ended."
  echo ""
done

# ── Final review session ──
echo ""
echo "=========================================="
echo "  MODULE REVIEW: ${MODULE_UPPER}"
echo "  Comparing built code against spec"
echo "=========================================="
echo ""

if [ -n "$SPEC_PATH" ]; then
  REVIEW_PROMPT="You are reviewing the ${MODULE_UPPER} module after all tickets were built. Read the original feature spec at ${SPEC_PATH}. Then read all source code in src/features/${FEATURE}/. Compare what was actually built against what the spec intended. For each area: (1) what the spec says, (2) what the code does, (3) whether they match. If there are deviations, explain each one and ask me: is this deviation acceptable, or should we fix it? If we need to fix, create a plan for the fix. This is a verification session — be thorough."
else
  REVIEW_PROMPT="You are reviewing the ${MODULE_UPPER} module after all tickets were built. Read docs/kanban/${MODULE}.md and verify all tickets are marked done. Check that the implementations are correct by reading the relevant source code. Report any issues found."
fi

cd "$PROJECT_ROOT"
claude "$REVIEW_PROMPT"

echo ""
echo "=========================================="
echo "  MODULE ${MODULE_UPPER} — BUILD COMPLETE"
echo "=========================================="
