#!/bin/bash
# hook-health.sh — Audit all registered hooks for staleness
# Reports ACTIVE / DORMANT / BROKEN / ASSUMED per hook
# Usage: bash scripts/hook-health.sh [--project-only]
#
# Reads hooks from .claude/settings.json (project) and ~/.claude/settings.json (global).
# Pass --project-only to skip global settings.
# Compatible with macOS bash 3.2 (no associative arrays).
# Requires: jq

set -o pipefail

PROJECT_SETTINGS=".claude/settings.json"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
HOOKS_DIR=".claude/hooks"
LEDGER_DIR="${GUARD_HOOKS_DIR:-.claude/guard-hooks}"
TODAY=$(date +%Y-%m-%d)

EVIDENCE_DAYS=7
EVIDENCE_CUTOFF=$(date -v-${EVIDENCE_DAYS}d +%s 2>/dev/null || date -d "-${EVIDENCE_DAYS} days" +%s 2>/dev/null)

PROJECT_ONLY=false
[[ "$1" == "--project-only" ]] && PROJECT_ONLY=true

# ---------------------------------------------------------------------------
# Evidence checking
# ---------------------------------------------------------------------------

check_evidence() {
  local script_name="$1"

  # Compaction hooks fire rarely — assume OK if the script exists
  case "$script_name" in
    pre-compact.sh|post-compact.sh)
      echo "RARE"
      return ;;
  esac

  # Check ledger files for recent activity
  for ledger_file in "$LEDGER_DIR"/.*; do
    [[ ! -f "$ledger_file" ]] && continue
    local mtime
    mtime=$(stat -f %m "$ledger_file" 2>/dev/null || stat -c %Y "$ledger_file" 2>/dev/null || echo 0)
    if [[ "$mtime" -ge "$EVIDENCE_CUTOFF" ]]; then
      local ledger_name
      ledger_name=$(basename "$ledger_file")
      # Match ledger to hook by naming convention
      case "$script_name" in
        edit-timestamp.sh)    [[ "$ledger_name" == ".edit-timestamp" ]] && echo "LEDGER" && return ;;
        search-tracker.sh)    [[ "$ledger_name" == ".search-ledger" ]] && echo "LEDGER" && return ;;
        verify-tracker.sh)    [[ "$ledger_name" == ".verify-ledger" ]] && echo "LEDGER" && return ;;
        track-deliverable.sh) [[ "$ledger_name" == ".deliverables-ledger" ]] && echo "LEDGER" && return ;;
        build-gate.sh)        [[ "$ledger_name" == ".build-gate-fired" || "$ledger_name" == ".build-gate-cleared" ]] && echo "FLAG" && return ;;
        deliverable-guard.sh) [[ "$ledger_name" == ".deliverable-guard-fired" ]] && echo "FLAG" && return ;;
      esac
    fi
  done

  echo "NONE"
}

# ---------------------------------------------------------------------------
# Extract hooks from settings JSON
# ---------------------------------------------------------------------------
extract_hooks() {
  local file="$1"
  [[ ! -f "$file" ]] && return

  jq -r '
    .hooks // {} | to_entries[] |
    .key as $trigger |
    .value[] |
    (.matcher // "none") as $matcher |
    .hooks[] |
    [$trigger, $matcher, .command] |
    @tsv
  ' "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== HOOK HEALTH — $TODAY ==="
echo ""

ACTIVE_COUNT=0
DORMANT_COUNT=0
BROKEN_COUNT=0
ASSUMED_COUNT=0
ACTIVE_LINES=""
DORMANT_LINES=""
BROKEN_LINES=""
ASSUMED_LINES=""
SEEN_KEYS=""

HOOK_DATA=$(mktemp)
trap 'rm -f "$HOOK_DATA"' EXIT

extract_hooks "$PROJECT_SETTINGS" > "$HOOK_DATA"
if [[ "$PROJECT_ONLY" != "true" && -f "$GLOBAL_SETTINGS" ]]; then
  extract_hooks "$GLOBAL_SETTINGS" >> "$HOOK_DATA"
fi

while IFS=$'\t' read -r trigger matcher command; do
  script_path=$(echo "$command" | grep -oE '[^ ]+\.sh' | head -1)
  script_name=$(basename "$script_path" 2>/dev/null)
  [[ -z "$script_name" ]] && continue

  key="${trigger}:${script_name}"
  if echo "$SEEN_KEYS" | grep -qF "$key"; then
    continue
  fi
  SEEN_KEYS="${SEEN_KEYS} ${key}"

  matcher_label=""
  [[ "$matcher" != "none" ]] && matcher_label=":$matcher"
  trigger_display="${trigger}${matcher_label}"

  # Check if script exists (try both relative and in hooks dir)
  SCRIPT_EXISTS=false
  [[ -f "$script_path" ]] && SCRIPT_EXISTS=true
  [[ -f "$HOOKS_DIR/$script_name" ]] && SCRIPT_EXISTS=true

  if [[ "$SCRIPT_EXISTS" == "false" ]]; then
    BROKEN_LINES="${BROKEN_LINES}$(printf "    %-28s %-24s MISSING" "$script_name" "$trigger_display")\n"
    BROKEN_COUNT=$((BROKEN_COUNT + 1))
    continue
  fi

  evidence=$(check_evidence "$script_name")

  case "$evidence" in
    RARE)
      ASSUMED_LINES="${ASSUMED_LINES}$(printf "    %-28s %-24s rare event — structural OK" "$script_name" "$trigger_display")\n"
      ASSUMED_COUNT=$((ASSUMED_COUNT + 1))
      ;;
    FLAG|LEDGER)
      ACTIVE_LINES="${ACTIVE_LINES}$(printf "    %-28s %-24s evidence: %s" "$script_name" "$trigger_display" "$evidence")\n"
      ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
      ;;
    NONE)
      DORMANT_LINES="${DORMANT_LINES}$(printf "    %-28s %-24s no evidence in ${EVIDENCE_DAYS}d" "$script_name" "$trigger_display")\n"
      DORMANT_COUNT=$((DORMANT_COUNT + 1))
      ;;
  esac
done < "$HOOK_DATA"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

if [[ $ACTIVE_COUNT -gt 0 ]]; then
  echo "  ACTIVE   ($ACTIVE_COUNT)"
  echo -e "$ACTIVE_LINES" | grep -v '^$'
  echo ""
fi

if [[ $DORMANT_COUNT -gt 0 ]]; then
  echo "  DORMANT  ($DORMANT_COUNT)"
  echo -e "$DORMANT_LINES" | grep -v '^$'
  echo ""
fi

if [[ $ASSUMED_COUNT -gt 0 ]]; then
  echo "  ASSUMED  ($ASSUMED_COUNT)"
  echo -e "$ASSUMED_LINES" | grep -v '^$'
  echo ""
fi

if [[ $BROKEN_COUNT -gt 0 ]]; then
  echo "  BROKEN   ($BROKEN_COUNT)"
  echo -e "$BROKEN_LINES" | grep -v '^$'
  echo ""
fi

TOTAL=$((ACTIVE_COUNT + DORMANT_COUNT + ASSUMED_COUNT + BROKEN_COUNT))
echo "=== $TOTAL hooks checked ==="
