#!/bin/bash
# verify-guard.sh — Stop hook
# Blocks responses that claim verification without running verification commands.
#
# Pattern: catches performative verification — saying "done" without doing.
# Reference: arxiv 2507.11473 (models are faithful to CoT only 25-41% of the time)
#
# Requires: verify-tracker.sh logging to .verify-ledger

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)

# Second pass (after block): let through, clean up
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
    rm -f "$LEDGER_DIR/.verify-ledger"
    exit 0
fi

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[[ -z "$LAST_MSG" ]] && exit 0

# Trigger phrases — words that imply "I checked and it works"
TRIGGERS="verified|confirmed|all passing|build passes|tests pass|everything works|all green|all healthy|fix confirmed|successfully (updated|fixed|deployed|integrated)|working now|works now|deployed and verified|shipped and working"

if ! echo "$LAST_MSG" | grep -iqE "$TRIGGERS"; then
    rm -f "$LEDGER_DIR/.verify-ledger"
    exit 0
fi

# Verification claim detected. Check the ledger.
if [[ ! -f "$LEDGER_DIR/.verify-ledger" ]]; then
    cat << 'EOF'
{
  "decision": "block",
  "reason": "VERIFY GUARD: You claimed something was verified/confirmed, but the verify ledger is empty — no version checks, test runs, status checks, or health checks were found. Run the actual verification command before claiming the result. (arxiv 2507.11473: models are faithful only 25-41% of the time)"
}
EOF
    exit 0
fi

# Ledger exists — verification commands were run. Allow.
rm -f "$LEDGER_DIR/.verify-ledger"
exit 0
