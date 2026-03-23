---
name: orient
description: "Session start — reads continuity from last /ship, collects live state, presents structured report. Evidence-based orientation, not conversation recall."
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

Adjust these paths to match your project. Set to empty string to skip.

```
CONTINUITY_FILE=".claude/last-session.md"   # Written by /ship
GOALS_FILE=""                                # e.g., "goals.md", "TODO.md"
REMINDERS_FILE=""                            # e.g., ".claude/reminders.md"
GROUNDING_FILES=""                           # Comma-separated files to read silently (e.g., "ARCHITECTURE.md,CONVENTIONS.md")
```

---

### Step 0: Grounding (optional)

If GROUNDING_FILES is set, read each file silently. These are absorbed into your context for the session — do not summarize them in the report.

---

### Step 1: Continuity

Read CONTINUITY_FILE (default: `.claude/last-session.md`).

If the file exists, extract:
- (a) What was worked on last session
- (b) What is unresolved / carried forward

If the file does not exist, note "No continuity file found." and continue.

---

### Step 2: Goals (optional)

**Skip if GOALS_FILE is empty or the file doesn't exist.**

Read the goals file. Extract:
- Active threads / in-progress work
- Recently completed items
- Any watchlist or deferred items

---

### Step 3: Reminders (optional)

**Skip if REMINDERS_FILE is empty or the file doesn't exist.**

Read the reminders file. Compare each unchecked item against today's date. Surface items that are due today or overdue.

Expected format: `- [ ] YYYY-MM-DD: Description`

If none are due, note "None due."

---

### Step 4: Git State

Run these commands and save the output:

```bash
echo "=== BRANCH ==="
git branch --show-current

echo "=== STATUS ==="
git status --short

echo "=== RECENT COMMITS ==="
git log --oneline -10
```

---

### Step 5: Custom State Collectors

**Customization point.** Add your own checks here — whatever matters for your project:

```bash
# Examples (uncomment and adapt):

# echo "=== TESTS ==="
# npm test 2>&1 | tail -5

# echo "=== BUILD ==="
# npm run build 2>&1 | tail -3

# echo "=== DEPENDENCIES ==="
# npm outdated 2>&1 || echo "All current"

# echo "=== DOCKER ==="
# docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null
```

The rule: collect from commands, not from memory. Whatever you add here flows into the report.

---

### Step 6: Structured Report

Present the report in EXACTLY this format. Every section present, every time. Do not add commentary outside the report.

```
=== ORIENT — [today's date] ===

CONTINUITY:
  [2-3 lines from last-session.md: what was done, key decisions]
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

[CUSTOM SECTIONS]
  [output from Step 5 collectors, if any]

ACTIVE THREADS:
  - [from goals file, one per line]
  [or "No goals file configured."]

ALERTS:
  [any conditions that need attention]
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
