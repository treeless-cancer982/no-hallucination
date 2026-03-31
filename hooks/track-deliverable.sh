#!/bin/bash
# track-deliverable.sh — PostToolUse tracker for Write|Edit
# Logs files written outside the project root to the deliverables ledger.
# The deliverable-guard.sh Stop hook reads this ledger.

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Get project root (where .claude/ lives)
PROJECT_ROOT="$(pwd)"

# Only track files OUTSIDE the project
case "$FILE_PATH" in
    "$PROJECT_ROOT"/*) exit 0 ;;  # Inside project — skip
esac

# Log to ledger
mkdir -p "$LEDGER_DIR"
echo -e "$(date +%H:%M:%S)\t$FILE_PATH" >> "$LEDGER_DIR/.deliverables-ledger"

exit 0
