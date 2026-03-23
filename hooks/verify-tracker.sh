#!/bin/bash
# verify-tracker.sh — PostToolUse for Bash
# Logs verification-like commands (version checks, test runs, status checks).
# verify-guard.sh reads this ledger at Stop time.

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[[ "$TOOL" != "Bash" ]] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

# Match verification-like commands
# Version checks, test runs, build checks, status checks, health checks
if echo "$CMD" | grep -qE '(--version|version|npm run build|npm test|pytest|jest|cargo test|go test|make test|systemctl (status|is-active)|curl.*-[sI]|git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(status|diff|log)|health|verify|test -[fedrwx]|grep -[qcl]|wc -[lcw]|python3 -c|node -e)'; then
    mkdir -p "$LEDGER_DIR"
    TIMESTAMP=$(date +%H:%M:%S)
    echo "${TIMESTAMP} ${CMD:0:120}" >> "$LEDGER_DIR/.verify-ledger"
fi

exit 0
