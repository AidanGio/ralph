#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop

set -e

# Defaults
TOOL="claude"
MAX_ITERATIONS=10

# Help function
show_help() {
  echo "Ralph Wiggum - Long-running AI agent loop"
  echo ""
  echo "Usage: ./ralph.sh [options]"
  echo ""
  echo "Options:"
  echo "  -t, --tool <name>      AI tool to use: claude, codex, gemini, agent (default: claude)"
  echo "  -n, --iterations <n>   Max iterations to run (default: 10)"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./ralph.sh                        # Use defaults (claude, 10 iterations)"
  echo "  ./ralph.sh -t codex -n 5          # Use codex with 5 iterations"
  echo "  ./ralph.sh -t gemini -n 20"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--tool)
      TOOL="$2"
      shift 2
      ;;
    -n|--iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "claude" && "$TOOL" != "codex" && "$TOOL" != "gemini" && "$TOOL" != "agent" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'claude', 'codex', 'gemini', or 'agent'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LOGS_DIR="$SCRIPT_DIR/logs"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    # Archive logs if they exist
    if [ -d "$LOGS_DIR" ] && [ "$(ls -A "$LOGS_DIR" 2>/dev/null)" ]; then
      cp -r "$LOGS_DIR" "$ARCHIVE_FOLDER/"
      rm -rf "$LOGS_DIR"/*
    fi
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Validate PRD exists
if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found at $PRD_FILE"
  exit 1
fi

# Show remaining stories
REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "?")
TOTAL=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "?")
echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"
echo "Stories: $REMAINING of $TOTAL remaining"

for i in $(seq 1 $MAX_ITERATIONS); do
  ITER_START=$(date +%s)
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "═══════════════════════════════════════════════════════"
  
  # Run the selected tool with the ralph prompt (tool-specific invocation)
  PROMPT_FILE="$SCRIPT_DIR/prompt.md"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  OUTPUT_FILE="$LOGS_DIR/iteration-${i}-${TIMESTAMP}.log"
  
  if [[ "$TOOL" == "claude" ]]; then
    # Claude CLI: --dangerously-skip-permissions skips all prompts, --print for non-interactive output
    script -q "$OUTPUT_FILE" claude --dangerously-skip-permissions --print "$(cat "$PROMPT_FILE")" || true
  elif [[ "$TOOL" == "codex" ]]; then
    # Codex CLI: exec for non-interactive, --yolo disables sandbox + auto-approves all
    script -q "$OUTPUT_FILE" codex exec --yolo "$(cat "$PROMPT_FILE")" || true
  elif [[ "$TOOL" == "gemini" ]]; then
    # Gemini CLI: --yolo auto-approves all tool calls, -p for non-interactive prompt
    script -q "$OUTPUT_FILE" gemini --yolo -p "$(cat "$PROMPT_FILE")" || true
  elif [[ "$TOOL" == "agent" ]]; then
    # Cursor Agent CLI: --print for non-interactive, --force for auto file changes
    script -q "$OUTPUT_FILE" agent --print --force "$(cat "$PROMPT_FILE")" || true
  fi
  
  # Strip ANSI codes for clean parsing (log file is kept in logs/)
  OUTPUT=$(cat "$OUTPUT_FILE" 2>/dev/null | sed $'s/\x1b\[[0-9;]*m//g' | tr -d '\r') || true
  echo "  Log saved: $OUTPUT_FILE"
  
  # Check if all stories now pass (primary completion check)
  REMAINING_NOW=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "1")
  if [ "$REMAINING_NOW" = "0" ]; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "All stories now pass. Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  # Show iteration timing
  ITER_END=$(date +%s)
  ITER_DURATION=$((ITER_END - ITER_START))
  echo "Iteration $i complete (${ITER_DURATION}s). Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
