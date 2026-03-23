#!/bin/bash
# build-gate.sh — PreToolUse for Write|Edit
# Blocks the first infrastructure file edit unless investigation was done.
# Fires once per session, then allows all subsequent edits.
#
# "Trivial fix" in the response bypasses the gate.
#
# Infrastructure = *.sh, *.py, *.js, .claude/hooks/*, .claude/skills/*

LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"

INPUT=$(cat)

# If gate already cleared or already fired, allow
[[ -f "$LEDGER_DIR/.build-gate-cleared" ]] && exit 0
[[ -f "$LEDGER_DIR/.build-gate-fired" ]] && exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Only gate infrastructure files
IS_INFRA=false
case "$FILE_PATH" in
    *.sh) IS_INFRA=true ;;
    *.py) IS_INFRA=true ;;
    *.js) IS_INFRA=true ;;
    */.claude/hooks/*) IS_INFRA=true ;;
    */.claude/skills/*) IS_INFRA=true ;;
esac

[[ "$IS_INFRA" == "false" ]] && exit 0

# Infrastructure edit detected without investigation. Fire the gate.
mkdir -p "$LEDGER_DIR"
touch "$LEDGER_DIR/.build-gate-fired"

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BUILD GATE: You are editing infrastructure (hook/skill/script) without investigating first. Before modifying infrastructure: (1) Read the current implementation, (2) Diagnose with evidence, (3) Search for existing solutions, (4) Propose the change. Say 'trivial fix' if this is a one-line change."}}
EOF

exit 0
