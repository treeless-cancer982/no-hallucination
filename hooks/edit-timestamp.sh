#!/bin/bash
# edit-timestamp.sh — PostToolUse for Write|Edit
# Records timestamp of first file edit in session.
# proof-guard.sh uses this to check before/after ordering.

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

TS_FILE="$LEDGER_DIR/.edit-timestamp"
[[ -f "$TS_FILE" ]] && exit 0

mkdir -p "$LEDGER_DIR"
date +%H:%M:%S > "$TS_FILE"

exit 0
