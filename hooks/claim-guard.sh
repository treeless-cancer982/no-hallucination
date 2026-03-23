#!/bin/bash
# claim-guard.sh — Stop hook
# Blocks responses that claim something doesn't exist without searching.
#
# By default, requires at least 1 search before a negative claim.
# Configure GUARD_HOOKS_SEARCH_SCOPES to require searches across multiple directories.
#
# Requires: search-tracker.sh logging to .search-ledger

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)

# Second pass (after block): let through, clean up
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
    rm -f "$LEDGER_DIR/.search-ledger"
    exit 0
fi

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[[ -z "$LAST_MSG" ]] && exit 0

# Trigger phrases — negative existential claims
TRIGGERS="doesn't exist|does not exist|not found|no trace|was lost|can't find|cannot find|no such|there is no|couldn't find|nothing matching|has been lost|no evidence"

if ! echo "$LAST_MSG" | grep -iqE "$TRIGGERS"; then
    rm -f "$LEDGER_DIR/.search-ledger"
    exit 0
fi

# Negative claim detected. Check search coverage.
LEDGER="$LEDGER_DIR/.search-ledger"

if [[ ! -f "$LEDGER" ]]; then
    cat << 'EOF'
{
  "decision": "block",
  "reason": "CLAIM GUARD: You said something doesn't exist, but you ran ZERO searches. Look before you speak. Use Grep, Glob, or search commands before claiming something isn't there."
}
EOF
    exit 0
fi

# If search scopes are configured, check each was searched
# Set GUARD_HOOKS_SEARCH_SCOPES as colon-separated list, e.g. "src:tests:docs"
if [[ -n "$GUARD_HOOKS_SEARCH_SCOPES" ]]; then
    IFS=':' read -ra SCOPES <<< "$GUARD_HOOKS_SEARCH_SCOPES"
    REPOS_SEARCHED=$(sort -u "$LEDGER" | tr '\n' ' ')
    MISSING=""

    for scope in "${SCOPES[@]}"; do
        if ! echo "$REPOS_SEARCHED" | grep -q "$scope"; then
            MISSING="${MISSING:+$MISSING, }$scope"
        fi
    done

    if [[ -n "$MISSING" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "CLAIM GUARD: You said something doesn't exist, but you didn't search: ${MISSING}. Search all configured scopes before making that claim."
}
EOF
        exit 0
    fi
fi

# Searches were run (and scopes satisfied if configured). Allow.
rm -f "$LEDGER_DIR/.search-ledger"
exit 0
