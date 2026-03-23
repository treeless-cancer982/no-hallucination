---
name: orient
description: "Full session start — reads continuity, goals, reminders, collects git + custom state, presents structured report. Production-grade with extension points for dependencies, bridges, and domain metrics."
version: "1.0"
user-invocable: true
effort: medium
allowed-tools: Read, Glob, Grep, Bash
---

## EXECUTE NOW

Run ALL steps mechanically. Do not skip steps. Do not summarize early. Collect all data first, then present the report once at the end.

**CRITICAL: Orient from files and commands, not from what you think you remember.** If you haven't read it this session, you don't know it.

After the report, say nothing else. No suggestions, no "do you want to proceed?"

### Configuration

```
CONTINUITY_FILE=".claude/last-session.md"   # Written by /ship
GOALS_FILE="goals.md"                        # Your active threads / TODO file
REMINDERS_FILE=".claude/reminders.md"        # Date-based reminders
GROUNDING_FILES=""                           # Comma-separated files to read silently
```

---

### Phase 1: Read Context (parallel)

Execute steps 0-4 in parallel — they are independent reads.

**Step 0 — Grounding (optional):** If GROUNDING_FILES is set, read each file silently. Do not summarize in the report — absorb for the session.

**Step 1 — Continuity:** Read CONTINUITY_FILE. Extract:
- (a) What was worked on last session
- (b) What is unresolved / carried forward

If the file does not exist, note "No continuity file found."

**Step 2 — Goals:** Read GOALS_FILE. Extract:
- **Active Threads** — in-progress work
- **Completed** — recently finished items
- **Deferred/Watchlist** — items parked for later

If the file does not exist, note "No goals file configured."

**Step 3 — Reminders:** Read REMINDERS_FILE. Compare each unchecked item (`- [ ] YYYY-MM-DD:`) against today's date. Surface items due today or overdue. If none due, note "None due." If no file, note "No reminders file configured."

**Step 4 — Git State:**

```bash
echo "=== BRANCH ==="
git branch --show-current

echo "=== STATUS ==="
git status --short

echo "=== RECENT COMMITS ==="
git log --oneline -10

echo "=== UNCOMMITTED CHANGES ==="
git diff --stat
```

---

### Phase 2: Extended State Collection (parallel)

Execute all enabled checks in parallel. Uncomment the sections you need.

**Step 5 — Dependencies (uncomment to enable):**
```bash
# echo "=== DEPENDENCIES ==="
# npm outdated 2>&1 || echo "All current"
#
# --- or for Python: ---
# pip list --outdated 2>&1 | head -20
#
# --- or run a custom checker: ---
# python3 ops/scripts/check-updates.py 2>&1
```

**Step 6 — Test Suite Health (uncomment to enable):**
```bash
# echo "=== TESTS ==="
# npm test 2>&1 | tail -10
#
# --- or: ---
# pytest --tb=no -q 2>&1 | tail -5
```

**Step 7 — Build Status (uncomment to enable):**
```bash
# echo "=== BUILD ==="
# npm run build 2>&1 | tail -5
#
# --- or check CI: ---
# gh run list --limit 3 --json conclusion,name,headBranch --template '{{range .}}{{.name}} ({{.headBranch}}): {{.conclusion}}{{"\n"}}{{end}}'
```

**Step 8 — Service Health (uncomment to enable):**
```bash
# echo "=== SERVICES ==="
# docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null
#
# --- or check an API: ---
# curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health
```

**Step 9 — Custom Metrics (uncomment to enable):**
```bash
# echo "=== CUSTOM ==="
# Example: count files in a processing queue
# ls intake/*.md 2>/dev/null | wc -l | xargs echo "Intake queue:"
#
# Example: check disk usage
# df -h . | tail -1
#
# Example: count TODO/FIXME in codebase
# grep -r "TODO\|FIXME" src/ --include="*.ts" | wc -l | xargs echo "TODOs:"
```

---

### Phase 3: Structured Report

Present the report in EXACTLY this format. Every section present, every time. Do not add commentary outside the report.

```
=== ORIENT — [today's date] ===

CONTINUITY:
  [2-3 lines from continuity file: what was done, key decisions]
  [or "No continuity file found."]

UNRESOLVED (carried forward):
  - [each unresolved item, one per line]
  [or "None."]

REMINDERS:
  [due/overdue items with dates]
  [or "None due." or "No reminders file configured."]

GIT:
  Branch: [name]
  Status: [clean | list of changes]
  Recent: [last 3-5 commit summaries]

[DEPENDENCIES:]
  [output from Step 5, if enabled]

[TESTS:]
  [output from Step 6, if enabled]

[BUILD:]
  [output from Step 7, if enabled]

[SERVICES:]
  [output from Step 8, if enabled]

[CUSTOM:]
  [output from Step 9, if enabled]

ACTIVE THREADS:
  - [from goals file, one per line]
  [or "No goals file configured."]

ALERTS:
  [any conditions that need attention — failing tests, stale deps, queue backlog]
  [or "None."]

=== Orient complete. ===
```

---

## Edge Cases

- **No continuity file:** Report "No continuity file found." Continue normally.
- **No goals file:** Report "No goals file configured." Continue normally.
- **No reminders file:** Report "No reminders file configured." Continue normally.
- **Command fails:** Report the error verbatim. Do not guess or hedge. Continue to next step.
- **Empty sections:** Always print the section header. Use "None." for empty content.
- **After the report:** Say nothing. No "Would you like to..." No suggestions. Let the data speak.
