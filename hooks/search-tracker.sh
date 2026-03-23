#!/bin/bash
# search-tracker.sh — PostToolUse for Grep|Glob|Bash
# Logs which directories were searched. claim-guard.sh reads this at Stop.

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"
LEDGER="$LEDGER_DIR/.search-ledger"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
    Grep|Glob)
        SEARCH_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // "."')
        ;;
    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        # Only track search-like commands
        echo "$CMD" | grep -qE '(grep|rg|find |ls |cat )' || exit 0
        SEARCH_PATH=$(echo "$CMD" | grep -oE '(/[^ "]+)' | head -1)
        [[ -z "$SEARCH_PATH" ]] && SEARCH_PATH="."
        ;;
    *) exit 0 ;;
esac

# Normalize to scope name
# If GUARD_HOOKS_SEARCH_SCOPES is set (colon-separated), match against those
# Otherwise just log the raw path
if [[ -n "$GUARD_HOOKS_SEARCH_SCOPES" ]]; then
    IFS=':' read -ra SCOPES <<< "$GUARD_HOOKS_SEARCH_SCOPES"
    for scope in "${SCOPES[@]}"; do
        if echo "$SEARCH_PATH" | grep -q "$scope"; then
            mkdir -p "$LEDGER_DIR"
            echo "$scope" >> "$LEDGER"
            exit 0
        fi
    done
    # Default: log as current directory
    mkdir -p "$LEDGER_DIR"
    echo "." >> "$LEDGER"
else
    mkdir -p "$LEDGER_DIR"
    echo "$SEARCH_PATH" >> "$LEDGER"
fi

exit 0
