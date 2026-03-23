#!/bin/bash
# proof-guard.sh — Stop hook
# Blocks responses that claim something was fixed without before/after evidence.
#
# Layering: verify-guard checks "did you run ANY check?"
#           proof-guard checks "did you run checks on BOTH SIDES of the change?"
#
# Requires: verify-tracker.sh logging to .verify-ledger
#           edit-timestamp.sh logging to .edit-timestamp

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)

# Second pass (after block): let through, clean up
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
    rm -f "$LEDGER_DIR/.edit-timestamp"
    exit 0
fi

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[[ -z "$LAST_MSG" ]] && exit 0

# Trigger phrases — words that imply "I fixed the thing"
TRIGGERS="(fixed|resolved|corrected|patched|deployed|shipped|working now|works now|passes now|all green|all passing|successfully (fixed|updated|deployed|patched|integrated))"

if ! echo "$LAST_MSG" | grep -iqE "$TRIGGERS"; then
    exit 0
fi

# Fix claim detected. Need before/after evidence.
VERIFY_LEDGER="$LEDGER_DIR/.verify-ledger"
EDIT_TS_FILE="$LEDGER_DIR/.edit-timestamp"

# No verify ledger = verify-guard already caught this. Don't double-block.
[[ ! -f "$VERIFY_LEDGER" ]] && exit 0

# No edit timestamp = no Write/Edit happened. Might be pure Bash fixes.
# Fall back to: need at least 2 verification entries.
if [[ ! -f "$EDIT_TS_FILE" ]]; then
    ENTRY_COUNT=$(wc -l < "$VERIFY_LEDGER" | tr -d ' ')
    if [[ "$ENTRY_COUNT" -lt 2 ]]; then
        cat << 'EOF'
{
  "decision": "block",
  "reason": "PROOF GUARD: You claimed something was fixed, but the verify ledger has only 1 entry. Before/after proof requires at least 2 checks — one showing the problem, one showing it's resolved."
}
EOF
    fi
    exit 0
fi

EDIT_TS=$(head -1 "$EDIT_TS_FILE")

# Check for verify entries before AND after the edit timestamp
HAS_BEFORE=false
HAS_AFTER=false

while IFS= read -r line; do
    ENTRY_TS=$(echo "$line" | cut -d' ' -f1)
    if [[ "$ENTRY_TS" < "$EDIT_TS" ]]; then
        HAS_BEFORE=true
    fi
    if [[ "$ENTRY_TS" > "$EDIT_TS" ]]; then
        HAS_AFTER=true
    fi
done < "$VERIFY_LEDGER"

if $HAS_BEFORE && $HAS_AFTER; then
    exit 0
fi

# Build specific failure message
if ! $HAS_BEFORE && ! $HAS_AFTER; then
    DETAIL="no verification commands ran before or after the edit"
elif ! $HAS_BEFORE; then
    DETAIL="no verification BEFORE the edit (first edit at $EDIT_TS). You showed the after-state but not the before-state"
else
    DETAIL="no verification AFTER the edit (first edit at $EDIT_TS). You showed the before-state but didn't verify the after-state"
fi

cat << EOF
{
  "decision": "block",
  "reason": "PROOF GUARD: You claimed something was fixed, but $DETAIL. Before/after proof required: (1) show the broken state, (2) make the fix, (3) show the fixed state."
}
EOF

exit 0
