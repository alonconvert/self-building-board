#!/bin/bash
# build-module.sh — Build all open tickets in a module sequentially.
# Each ticket gets its own fresh Claude Code session.
# Features: spinner, elapsed time, progress bar, ETA, color output,
# live status file for dashboard polling.
#
# Usage: bash build-module.sh <module>
#   e.g.: bash build-module.sh meta
#
# Set PROJECT_DIR env var to point to your project, or it defaults to ../project

# Don't use set -e — we want to continue even if one session fails
MODULE="${1:?Usage: bash build-module.sh <module>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR"

# Project root: set via env var, or default to ../project relative to this script
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_ROOT="$(cd "$PROJECT_DIR" && pwd)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../project" && pwd)"
fi

# ── Colors & Symbols ───────��────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'
BG_RED='\033[41m'

CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
ARROW="${CYAN}→${RESET}"

# ── Status file for dashboard live tracking ──────────���──────────────────
BUILD_STATUS_FILE="$DASHBOARD_DIR/.build-status.json"

write_build_status() {
  local status="$1" current_ticket="$2" current_num="$3" total="$4" elapsed="$5" module_key="$6"
  cat > "$BUILD_STATUS_FILE" << STATUSEOF
{
  "module": "${module_key}",
  "status": "${status}",
  "currentTicket": "${current_ticket}",
  "currentNum": ${current_num},
  "total": ${total},
  "elapsed": ${elapsed},
  "startedAt": "${BUILD_START_ISO}",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "succeeded": ${SUCCEEDED},
  "failed": [$(printf '"%s",' "${FAILED[@]}" | sed 's/,$//')]
}
STATUSEOF
}

clear_build_status() {
  rm -f "$BUILD_STATUS_FILE"
}

# ── Spinner with elapsed time ──────────��────────────────────────────────
SPINNER_PID=""

start_spinner() {
  local label="$1"
  local start_ts="$2"
  (
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while true; do
      local now=$(date +%s)
      local elapsed=$((now - start_ts))
      local mins=$((elapsed / 60))
      local secs=$((elapsed % 60))
      local time_str=$(printf "%dm %02ds" $mins $secs)
      printf "\r  ${CYAN}${frames[$i]}${RESET} ${label}  ${DIM}${time_str}${RESET}   " >&2
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.12
    done
  ) &
  SPINNER_PID=$!
}

stop_spinner() {
  if [ -n "$SPINNER_PID" ]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""
    printf "\r\033[K" >&2
  fi
}

# Clean up on exit
trap 'stop_spinner; clear_build_status' EXIT INT TERM

# ── Format elapsed time ─────────────────────���───────────────────────────
format_time() {
  local secs=$1
  if [ $secs -lt 60 ]; then
    echo "${secs}s"
  elif [ $secs -lt 3600 ]; then
    echo "$((secs / 60))m $((secs % 60))s"
  else
    echo "$((secs / 3600))h $((secs % 3600 / 60))m"
  fi
}

# ── Progress bar renderer ────���──────────────────────────────────────────
render_progress() {
  local done=$1 total=$2 width=30
  local filled=$((done * width / total))
  local empty=$((width - filled))
  local pct=$((done * 100 / total))

  local bar=""
  for ((j=0; j<filled; j++)); do bar+="█"; done
  for ((j=0; j<empty; j++)); do bar+="░"; done

  if [ $pct -eq 100 ]; then
    echo -e "  ${GREEN}[${bar}]${RESET} ${GREEN}${BOLD}${pct}%${RESET} ${GREEN}— All done!${RESET}"
  elif [ $pct -ge 50 ]; then
    echo -e "  ${CYAN}[${bar}]${RESET} ${BOLD}${pct}%${RESET} — ${done}/${total} tickets built"
  else
    echo -e "  ${YELLOW}[${bar}]${RESET} ${BOLD}${pct}%${RESET} — ${done}/${total} tickets built"
  fi
}

# ── Module-to-feature-dir mapping ───────────────────────────────────────
FEATURE=""
MODULES_FILE="$SCRIPT_DIR/modules.conf"
if [ -f "$MODULES_FILE" ]; then
  FEATURE=$(grep "^${MODULE}=" "$MODULES_FILE" | cut -d'=' -f2)
else
  echo -e "${YELLOW}WARNING: modules.conf not found. Feature spec lookup disabled.${RESET}"
fi

KANBAN_FILE="$PROJECT_ROOT/docs/kanban/${MODULE}.md"
SPEC_PATH=""
if [ -n "$FEATURE" ]; then
  SPEC_PATH="src/features/${FEATURE}/README.md"
fi

if [ ! -f "$KANBAN_FILE" ]; then
  echo -e "${RED}ERROR: Kanban file not found: $KANBAN_FILE${RESET}"
  exit 1
fi

# Extract open tickets: ticket rows that are NOT marked ✅ Done
TICKET_LINES=()
while IFS= read -r line; do
  TICKET_LINES+=("$line")
done < <(grep -E '^\|\s*[A-Z]+-[0-9]+' "$KANBAN_FILE" | grep -v '✅')

if [ ${#TICKET_LINES[@]} -eq 0 ]; then
  echo ""
  echo -e "  ${GREEN}${BOLD}No open tickets in ${MODULE} module.${RESET}"
  echo -e "  ${CHECK} All tickets are done!"
  echo ""
  exit 0
fi

# Parse ticket IDs and titles
TICKET_IDS=()
TICKET_TITLES=()
TICKET_NOTES=()
for line in "${TICKET_LINES[@]}"; do
  id=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  title=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
  notes=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
  TICKET_IDS+=("$id")
  TICKET_TITLES+=("$title")
  TICKET_NOTES+=("$notes")
done

TOTAL=${#TICKET_IDS[@]}
MODULE_UPPER="$(echo "$MODULE" | tr '[:lower:]' '[:upper:]')"
FAILED=()
SUCCEEDED=0
TICKET_TIMES=()
BUILD_START=$(date +%s)
BUILD_START_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Header ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo -e "  ${BG_BLUE}${WHITE} BUILD MODULE: ${MODULE_UPPER} ${RESET}"
echo -e "  ${BOLD}${TOTAL} open tickets${RESET} to build"
echo -e "${BOLD}═════════════════════���════════════════════${RESET}"
echo ""

# List all tickets that will be built
echo -e "  ${DIM}Tickets in queue:${RESET}"
for i in "${!TICKET_IDS[@]}"; do
  echo -e "  ${DIM}  $((i + 1)). ${TICKET_IDS[$i]} — ${TICKET_TITLES[$i]}${RESET}"
done
echo ""

# Initial progress
render_progress 0 "$TOTAL"
echo ""

# Write initial build status
write_build_status "running" "${TICKET_IDS[0]}" 0 "$TOTAL" 0 "$MODULE"

for i in "${!TICKET_IDS[@]}"; do
  TID="${TICKET_IDS[$i]}"
  TTITLE="${TICKET_TITLES[$i]}"
  TNOTES="${TICKET_NOTES[$i]}"
  NUM=$((i + 1))
  TICKET_START=$(date +%s)

  echo -e "  ${BOLD}────────────────────────────────────────${RESET}"
  echo -e "  ${ARROW} ${BOLD}[${NUM}/${TOTAL}] ${TID}${RESET}: ${TTITLE}"
  echo -e "  ${BOLD}────────────────────────────────────────${RESET}"
  echo ""

  SPEC_INSTRUCTION=""
  if [ -n "$SPEC_PATH" ]; then
    SPEC_INSTRUCTION="Read the feature spec at ${SPEC_PATH}. "
  fi

  NOTES_INSTRUCTION=""
  if [ -n "$TNOTES" ] && [ "$TNOTES" != "⬜ TODO" ]; then
    NOTES_INSTRUCTION=" Kanban notes: ${TNOTES}."
  fi

  PROMPT="You are building ticket ${TID} for the ${MODULE_UPPER} module. Ticket: ${TID} — ${TTITLE}.${NOTES_INSTRUCTION} ${SPEC_INSTRUCTION}Implement it completely following existing code patterns. After building: run npx tsc --noEmit and fix any type errors. Run npx vitest run for related tests and fix any failures. Then update docs/kanban/${MODULE}.md to mark ${TID} as done with notes on what was built. Commit and push. Then cd to ${DASHBOARD_DIR} and run: node generate.js && git add index.html && git commit -m 'Regenerate dashboard: ${TID} done' && git push && npx vercel deploy --prod --yes. Tell me which ticket you completed and summarize what was built."

  # Update status file for dashboard
  local_elapsed=$(( $(date +%s) - BUILD_START ))
  write_build_status "building" "$TID" "$NUM" "$TOTAL" "$local_elapsed" "$MODULE"

  # Start spinner
  start_spinner "${YELLOW}Building ${TID}${RESET} — ${DIM}${TTITLE}${RESET}" "$TICKET_START"

  # Run Claude in headless mode
  cd "$PROJECT_ROOT"
  CLAUDE_OUTPUT=$(claude -p "$PROMPT" --dangerously-skip-permissions 2>&1)
  CLAUDE_EXIT=$?

  # Stop spinner
  stop_spinner

  TICKET_END=$(date +%s)
  TICKET_ELAPSED=$((TICKET_END - TICKET_START))
  TICKET_TIMES+=("$TICKET_ELAPSED")

  if [ $CLAUDE_EXIT -eq 0 ]; then
    SUCCEEDED=$((SUCCEEDED + 1))
    echo -e "  ${CHECK} ${GREEN}${BOLD}${TID} completed${RESET} in ${BOLD}$(format_time $TICKET_ELAPSED)${RESET}"

    SUMMARY=$(echo "$CLAUDE_OUTPUT" | grep -E "^(Completed|Built|Created|Updated|Added|Implemented|New file|Tests:|✅)" | tail -5)
    if [ -n "$SUMMARY" ]; then
      echo ""
      echo -e "  ${DIM}Summary:${RESET}"
      while IFS= read -r sline; do
        echo -e "  ${DIM}  ${sline}${RESET}"
      done <<< "$SUMMARY"
    fi
  else
    FAILED+=("$TID")
    echo -e "  ${CROSS} ${RED}${BOLD}${TID} failed${RESET} after $(format_time $TICKET_ELAPSED)"

    ERROR_TAIL=$(echo "$CLAUDE_OUTPUT" | tail -3)
    if [ -n "$ERROR_TAIL" ]; then
      echo -e "  ${DIM}Last output:${RESET}"
      while IFS= read -r eline; do
        echo -e "  ${RED}  ${eline}${RESET}"
      done <<< "$ERROR_TAIL"
    fi
  fi
  echo ""

  # Updated progress bar
  render_progress "$SUCCEEDED" "$TOTAL"

  # Time estimate for remaining tickets
  REMAINING=$((TOTAL - NUM))
  if [ $REMAINING -gt 0 ] && [ ${#TICKET_TIMES[@]} -gt 0 ]; then
    TOTAL_TIME=0
    for t in "${TICKET_TIMES[@]}"; do TOTAL_TIME=$((TOTAL_TIME + t)); done
    AVG_TIME=$((TOTAL_TIME / ${#TICKET_TIMES[@]}))
    ETA=$((AVG_TIME * REMAINING))
    echo -e "  ${DIM}~$(format_time $ETA) remaining (${REMAINING} tickets × ~$(format_time $AVG_TIME) avg)${RESET}"
  fi
  echo ""

  # Update status file
  local_elapsed=$(( $(date +%s) - BUILD_START ))
  write_build_status "running" "${TID}" "$NUM" "$TOTAL" "$local_elapsed" "$MODULE"
done

# ── Summary ─────────────────────────────────���───────────────────────────
BUILD_END=$(date +%s)
BUILD_TOTAL=$((BUILD_END - BUILD_START))

echo ""
echo -e "${BOLD}════��═══════════════════════════��═════════${RESET}"
echo -e "  ${BOLD}BUILD SUMMARY: ${MODULE_UPPER}${RESET}"
echo -e "  ${BOLD}Total time:${RESET} $(format_time $BUILD_TOTAL)"
echo ""

for i in "${!TICKET_IDS[@]}"; do
  TID="${TICKET_IDS[$i]}"
  TIME_STR="—"
  if [ $i -lt ${#TICKET_TIMES[@]} ]; then
    TIME_STR="$(format_time ${TICKET_TIMES[$i]})"
  fi

  IS_FAILED=false
  for f in "${FAILED[@]}"; do
    if [ "$f" = "$TID" ]; then IS_FAILED=true; break; fi
  done

  if [ "$IS_FAILED" = true ]; then
    echo -e "  ${CROSS} ${TID} — ${RED}failed${RESET} (${TIME_STR})"
  else
    echo -e "  ${CHECK} ${TID} ��� ${GREEN}done${RESET} (${TIME_STR})"
  fi
done

echo ""
echo -e "  ${BOLD}Succeeded:${RESET} ${GREEN}${SUCCEEDED}${RESET}/${TOTAL}"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "  ${BOLD}Failed:${RESET} ${RED}${#FAILED[@]}${RESET} — ${FAILED[*]}"
  echo ""
  echo -e "  ${DIM}To retry: bash build-module.sh ${MODULE}${RESET}"
fi
echo -e "${BOLD}════════��═════════════════════════════════${RESET}"
echo ""

# Write final status
if [ ${#FAILED[@]} -eq 0 ]; then
  write_build_status "review" "" "$TOTAL" "$TOTAL" "$BUILD_TOTAL" "$MODULE"
else
  write_build_status "done_with_errors" "" "$SUCCEEDED" "$TOTAL" "$BUILD_TOTAL" "$MODULE"
fi

# Only run review if all tickets succeeded
if [ ${#FAILED[@]} -eq 0 ]; then
  echo -e "  ${BG_GREEN}${WHITE} MODULE REVIEW ${RESET}"
  echo -e "  ${DIM}Comparing built code against spec...${RESET}"
  echo ""

  if [ -n "$SPEC_PATH" ]; then
    REVIEW_PROMPT="You are reviewing the ${MODULE_UPPER} module after all tickets were built. Read the original feature spec at ${SPEC_PATH}. Then read all source code in src/features/${FEATURE}/. Compare what was actually built against what the spec intended. For each area: (1) what the spec says, (2) what the code does, (3) whether they match. If there are deviations, explain each one and ask me: is this deviation acceptable, or should we fix it? If we need to fix, create a plan for the fix. This is a verification session — be thorough."
  else
    REVIEW_PROMPT="You are reviewing the ${MODULE_UPPER} module after all tickets were built. Read docs/kanban/${MODULE}.md and verify all tickets are marked done. Check that the implementations are correct by reading the relevant source code. Report any issues found."
  fi

  REVIEW_START=$(date +%s)
  start_spinner "${MAGENTA}Running module review${RESET}" "$REVIEW_START"

  cd "$PROJECT_ROOT"
  claude -p "$REVIEW_PROMPT" --dangerously-skip-permissions 2>&1
  REVIEW_EXIT=$?

  stop_spinner

  REVIEW_ELAPSED=$(( $(date +%s) - REVIEW_START ))
  if [ $REVIEW_EXIT -eq 0 ]; then
    echo -e "  ${CHECK} ${GREEN}Review completed${RESET} in $(format_time $REVIEW_ELAPSED)"
  else
    echo -e "  ${CROSS} ${RED}Review had issues${RESET} — check output above"
  fi

  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${RESET}"
  echo -e "  ${GREEN}${BOLD}MODULE ${MODULE_UPPER} — BUILD COMPLETE${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════${RESET}"

  clear_build_status
else
  echo ""
  echo -e "  ${YELLOW}Skipping review — ${#FAILED[@]} ticket(s) still need building.${RESET}"
  echo -e "  ${DIM}Run 'bash build-module.sh ${MODULE}' again to continue.${RESET}"
  echo ""
fi
