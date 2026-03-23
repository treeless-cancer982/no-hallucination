---
name: ship
description: "End-of-session close — collect state from git, write continuity file from evidence, commit and push. Prevents hallucinated session summaries."
version: "1.0"
user-invocable: true
effort: medium
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

## EXECUTE NOW

Run ALL steps mechanically. Do not skip steps. Do not summarize early. Every claim must come from a command output, not from memory.

**CRITICAL: Generate the continuity file from git and file state, not from what you think happened.** The whole point of this skill is to prevent hallucinated session summaries.

### Configuration

Adjust these paths to match your project. Everything else is automatic.

```
CONTINUITY_FILE=".claude/last-session.md"   # Where to write session summary
GOALS_FILE=""                                # Set to your goals file path (e.g., "goals.md") or leave empty to skip
PUSH_AFTER_COMMIT=true                       # Set to false to commit without pushing
```

---

### Step 0: Idempotency Check

```bash
git log --oneline -1
```

If the last commit message starts with "Session close:", this session already shipped. **ABORT** — say "Already shipped" and stop. Do not double-ship.

---

### Step 1: Collect Session State

Run these and **save the raw output** — you will use it in Step 3:

```bash
echo "=== TIMESTAMP ==="
date "+%Y-%m-%d %H:%M %Z"

echo "=== GIT LOG (this session) ==="
git log --oneline -30

echo "=== GIT STATUS ==="
git status --short

echo "=== BRANCH ==="
git branch --show-current
```

**CHECKPOINT:** You must have git log and status output before proceeding. If any command failed, report the error and continue with what you have.

**Customization point:** Add your own state collectors here — test suite status, build output, dependency counts, whatever matters for your project. The rule is: collect it from a command, not from conversation memory.

---

### Step 2: Update Goals (optional)

**Skip this step if GOALS_FILE is empty or the file doesn't exist.**

If you have a goals file, read it and update based on the git log from Step 1:

- Completed threads: mark as done with a one-line summary and the date
- Active threads: update status with what was done this session
- Keep at most the last 2 sessions' completions to prevent unbounded growth

**Do NOT leave completed work in active threads.** This is the #1 source of stale session data — the next session sees "in progress" and either re-does the work or wastes time investigating.

---

### Step 3: Write Continuity File

**CHECKPOINT:** Verify you have outputs from Steps 1-2 before proceeding.

Write the continuity file using this template. Fill values ONLY from command outputs — paste the numbers, do not calculate or estimate:

```markdown
# Last Session — [TIMESTAMP from Step 1]

## What happened
- [one line per commit theme from GIT LOG — group related commits]

## Decisions
- [decisions visible in commit messages or goals updates]
- [if none: "None."]

## Unresolved
- [from GIT STATUS: uncommitted/untracked work]
- [from goals: active threads not closed]
- [if none: "None."]
```

**Constraints:**
- Max 15 lines in the body
- Every number and fact must come from a Step 1 output
- If you don't have data for a field, write "unknown" — never guess

After writing, verify length:
```bash
wc -l [CONTINUITY_FILE]
```
If over 25 lines total (including headers), trim the "What happened" section.

---

### Step 4: Commit and Push

Stage the files modified this session **by name** — never use `git add -A` or `git add .`:

```bash
git add [CONTINUITY_FILE]
# Add goals file if it was updated:
# git add [GOALS_FILE]
# Add any other files modified this session by name
git status --short
```

Review staged changes. Then commit:

```bash
git commit -m "Session close: [one-line summary from git log themes]"
```

If PUSH_AFTER_COMMIT is true:
```bash
git push
```

**FAILURE HANDLING:**
- If `git commit` fails (nothing to commit): skip commit, proceed to Step 5
- If `git push` fails: report error to user, **do NOT mark as shipped**

---

### Step 5: Final Verification

```bash
git status --short
git log --oneline -1
```

Both must succeed. Git status should show a clean working tree. If changes remain, report them — something was missed.

---

## Output Format

```
=== SESSION CLOSE ===

Commits: [N] this session

[Goals updated:]
  [- thread: closed/updated/unchanged]
  [or "No goals file configured."]

Unresolved:
  - [items carried forward]
  [or "None."]

Continuity: written ([N] lines)
Git: [committed and pushed (hash) | committed (hash) | nothing to commit | push failed]

=== Ship complete. ===
```
