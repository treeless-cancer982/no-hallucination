#!/bin/bash
# Pre-Compaction Hook — fires BEFORE Claude Code compacts context
# Purpose: Force state persistence while full context is still available
#
# Context compaction loses operational details, established patterns, and
# mid-task state. This hook injects a mandatory persistence protocol.

CONTINUITY_FILE="${CONTINUITY_FILE:-.claude/last-session.md}"

cat <<EOF
=== COMPACTION IMMINENT — PERSIST NOW ===

Context is about to be compacted. After compaction, you will lose
operational details, corrections, and mid-task state.

BEFORE COMPACTION COMPLETES:
  1. Write/update $CONTINUITY_FILE with: what you are doing,
     decisions made, current state, what's unresolved
  2. If any user corrections or preferences from this session
     aren't saved to files yet, write them NOW
  3. Note any files you're actively working on so you can
     re-read them after compaction

AFTER COMPACTION (treat as new session):
  1. Run /orient to re-ground from files
  2. Re-read any files relevant to the current task
  3. Only then resume work

=== END PRE-COMPACTION PROTOCOL ===
EOF
