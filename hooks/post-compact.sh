#!/bin/bash
# Post-Compaction Hook — fires AFTER Claude Code compacts context
# Purpose: Mechanically re-inject critical context into the degraded summary
#
# After compaction, the agent operates from a compressed summary that loses
# operational details, corrections, and mid-task state. This hook injects
# the minimum viable context to prevent cascading errors.
#
# Configure: Set CONTINUITY_FILE and GOALS_FILE below, or via environment.

CONTINUITY_FILE="${CONTINUITY_FILE:-.claude/last-session.md}"
GOALS_FILE="${GOALS_FILE:-}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

echo "=== CONTEXT COMPACTED — CRITICAL CONTEXT FOLLOWS ==="
echo ""

# 1. Last session continuity (primary grounding)
if [[ -f "$CONTINUITY_FILE" ]]; then
    echo "--- Last Session ---"
    cat "$CONTINUITY_FILE"
    echo ""
fi

# 2. Active thread titles (if goals file configured)
if [[ -n "$GOALS_FILE" && -f "$GOALS_FILE" ]]; then
    echo "--- Active Threads ---"
    grep -E "^###? " "$GOALS_FILE" | head -10
    echo ""
fi

# 3. Mandatory action
echo "ACTION REQUIRED: Run /orient before continuing any work."
echo "Do NOT trust the compacted summary for operational details."
echo "The summary above is lossy — /orient re-reads the actual files."
echo ""
echo "=== END POST-COMPACTION CONTEXT ==="
