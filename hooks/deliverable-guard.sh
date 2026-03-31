#!/bin/bash
# deliverable-guard.sh — Stop hook
# Checks if the session wrote files outside the project that may need tracking.
# Fires once per session — after blocking, writes a flag to prevent loops.
#
# Requires: track-deliverable.sh (PostToolUse tracker that populates the ledger)
# Ledger format: timestamp\tfile_path (one line per write/edit outside project root)

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"
LEDGER="$LEDGER_DIR/.deliverables-ledger"
GUARD_FLAG="$LEDGER_DIR/.deliverable-guard-fired"

INPUT=$(cat)

# Prevent infinite loops: if stop_hook_active, clean up and allow
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
    rm -f "$LEDGER" "$GUARD_FLAG"
    exit 0
fi

# If guard already fired this session, clean up and allow
if [[ -f "$GUARD_FLAG" ]]; then
    rm -f "$LEDGER" "$GUARD_FLAG"
    exit 0
fi

# If no ledger or empty ledger, nothing to guard
if [[ ! -s "$LEDGER" ]]; then
    rm -f "$LEDGER"
    exit 0
fi

# Count unique files
UNIQUE_FILES=$(cut -f2 "$LEDGER" | sort -u)
UNIQUE_COUNT=$(echo "$UNIQUE_FILES" | wc -l | tr -d ' ')

# Format the file list
FILE_LIST=""
while IFS= read -r f; do
    FILE_LIST="${FILE_LIST}\n  - ${f}"
done <<< "$UNIQUE_FILES"

# Set the guard flag so we don't block again
touch "$GUARD_FLAG"

# Block the stop
cat << EOF
{
  "decision": "block",
  "reason": "DELIVERABLE GUARD: This session wrote ${UNIQUE_COUNT} file(s) outside the project that may need tracking:${FILE_LIST}\n\nBefore ending, check whether any of these need:\n1. A reminder or follow-up task\n2. A note in your goals/TODO file\n3. Documentation or changelog entry\n\nIf none need tracking, say so explicitly and stop. If the deliverables are ephemeral (test output, scratch files), dismiss them."
}
EOF

exit 0
