# Claude Masterplan

**Stop your AI from hallucinating its own history.**

```
Agent edits auth.js, then says:
  "Fixed the authentication bug — verified all tests pass."

proof-guard fires:
  BLOCKED: You claimed something was fixed, but no verification ran
  before the edit. Show the broken state first, then the fix, then
  verify it works.

Agent runs: npm test (fails) → edits auth.js → npm test (passes)
Agent says:
  "Fixed the authentication bug. Tests failed before (3 failures),
   pass after (24/24). Diff: auth.js line 42."

proof-guard: ✓ (before + after evidence in ledger)
```

When a guard fires, Claude Code shows the block reason and the agent gets a second chance to produce evidence before continuing. No session stall — just enforced honesty.

## The Problem

AI agents hallucinate their own history. They orient from degraded conversation summaries, make confident claims about work they didn't verify, and write session summaries from memory instead of evidence. Across sessions, these small lies compound — Session N's hallucination becomes Session N+1's false premise.

> Models are faithful to their chain of thought only 25-41% of the time.
> — [Chain of Thought Monitorability (arxiv 2507.11473)](https://arxiv.org/abs/2507.11473)

## The Loop

```
/orient (start) ──→ guard hooks (during) ──→ /ship (close)
      ↑                                           │
      └──────────── last-session.md ←──────────────┘
```

1. **`/orient`** — Structured session start. Reads the continuity file from the last `/ship`, collects live state (git, goals, reminders), presents a structured report. Evidence-based orientation, not conversation recall.

2. **Guard hooks** — Epistemic enforcement during work. Seven hooks that watch what the agent actually does and block claims that don't match the evidence.

3. **`/ship`** — Session close. Writes a continuity file from `git log` and command outputs — never from conversation memory. What it writes is what `/orient` reads next session.

The continuity file is the handshake. When `/ship` writes accurately, `/orient` starts accurately, and the next session inherits truth instead of hallucination.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (any version with hooks and skills support)
- bash, jq (standard on macOS and Linux)
- git (for orient/ship state collection)

## Install

### Quick install (recommended)

```bash
git clone https://github.com/AlethiaQuizForge/claude-masterplan.git
cd your-project
/path/to/claude-masterplan/install.sh
```

The install script copies skills, hooks, and creates the ledger directory. If you already have a `settings.json`, it won't overwrite — you'll merge the hook wiring manually (see [Configuration](#configuration)).

### Manual install

```bash
git clone https://github.com/AlethiaQuizForge/claude-masterplan.git
```

**Full loop** (recommended):
```bash
mkdir -p .claude/skills .claude/hooks
cp -r skills/orient skills/ship .claude/skills/
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
# Merge settings.json into your .claude/settings.json
```

**Just the guards:** Copy only `hooks/` and `settings.json`.

**Just the lifecycle:** Copy only `skills/orient` and `skills/ship`.

## The Skills

### /orient — Session Start

Reads evidence, presents state. Says nothing else.

```
> orient

=== ORIENT — 2026-03-24 ===

CONTINUITY:
  Added rate limiting middleware, fixed pagination off-by-one.
  Sliding window chosen over fixed window for bursty traffic.

UNRESOLVED (carried forward):
  - Integration tests for rate limiter not written
  - docs/api.md needs rate limit headers documented

GIT:
  Branch: main
  Status: clean
  Recent:
    abc1234 Session close: rate limiter + pagination fix

ALERTS:
  None.

=== Orient complete. ===
```

### Customizing orient

Set paths at the top of `skills/orient/SKILL.md`:

```
CONTINUITY_FILE=".claude/last-session.md"   # Written by /ship
GOALS_FILE=""                                # e.g., "goals.md", "TODO.md"
REMINDERS_FILE=""                            # e.g., ".claude/reminders.md"
GROUNDING_FILES=""                           # Files to read silently at session start
```

Add custom state collectors in Step 5 — dependency checks, test status, Docker health, whatever matters for your project.

### /ship — Session Close

Writes continuity from evidence, not memory.

```
> /ship

=== SESSION CLOSE ===

Commits: 3 this session

Unresolved:
  - Integration tests for rate limiter not written
  - docs/api.md needs rate limit headers

Continuity: written (12 lines)
Git: committed and pushed (abc1234)

=== Ship complete. ===
```

### Customizing ship

Set paths at the top of `skills/ship/SKILL.md`:

```
CONTINUITY_FILE=".claude/last-session.md"
GOALS_FILE=""                                # Optional goals tracking
PUSH_AFTER_COMMIT=true                       # false to commit without pushing
```

**Key rules:**
- Every claim in the session summary comes from a command output (`git log`, `git status`)
- Files staged by name — never `git add -A`
- Idempotent — won't double-commit if run twice
- Goals file updated automatically (completed work moved out of active threads)

## The Guards

Seven hooks (3 guards + 3 trackers + 1 gate) using the **tracker-ledger-guard** pattern:

1. **Trackers** watch what the agent actually does — which commands it runs, which files it searches, when it edits files. They write entries to ledger files.
2. **Guards** read the agent's final response and check its claims against the ledger. If the claims don't match the evidence, the response is blocked.

### Guards (Stop hooks — check claims against evidence)

| Hook | What it catches |
|------|----------------|
| **verify-guard** | "All tests pass" — without running any tests |
| **proof-guard** | "Fixed the bug" — without before/after evidence |
| **claim-guard** | "Doesn't exist" — without searching first |

### Trackers (PostToolUse hooks — build the evidence ledger)

| Hook | What it records |
|------|----------------|
| **verify-tracker** | Verification commands (test runners, status checks) |
| **search-tracker** | Search commands (grep, glob, find) |
| **edit-timestamp** | When the first file edit happened |

### Gate (PreToolUse hook — require investigation before action)

| Hook | What it enforces |
|------|-----------------|
| **build-gate** | Investigation before editing infrastructure files |

### How the guards layer

```
Stop hook fires
  │
  ├─ verify-guard: "Did you run ANY verification command?"
  │   └─ No → BLOCK (run the check first)
  │   └─ Yes → pass to next guard
  │
  ├─ proof-guard: "Did you run checks BEFORE and AFTER the edit?"
  │   └─ No before → BLOCK (show the broken state first)
  │   └─ No after  → BLOCK (verify the fix)
  │   └─ Both      → pass to next guard
  │
  └─ claim-guard: "Did you SEARCH before saying it doesn't exist?"
      └─ No searches → BLOCK (look before you speak)
      └─ Searched    → allow
```

### Hook configuration

Set `GUARD_HOOKS_DIR` to change where ledger files are stored (default: `.claude/guard-hooks/`). Set `GUARD_HOOKS_SEARCH_SCOPES` for multi-directory search enforcement. Each guard has a `TRIGGERS` variable near the top of the script — add or remove phrases to match your workflow.

## Real-World Example

This kit was extracted from a production system where two AI agents coordinate across sessions — a knowledge scribe and a messenger. The orient and ship skills are extended with domain-specific state collectors (inter-agent bridge, dependency checker, knowledge graph metrics, processing pipeline verification).

<details>
<summary>Production orient output (multi-agent, extended)</summary>

```
=== ORIENT — 2026-03-23 ===

CONTINUITY:
  Processed 12 source documents into knowledge graph.
  Pipeline verification: all batches PASS. Graph fully connected.

UNRESOLVED (carried forward):
  - 3 items need cross-domain connections
  - Dependency: ws 8.19.0 → 8.20.0 (MINOR, awaiting approval)

BRIDGE (unread):
  Agent-2: "Config fix deployed. Service restored."

REMINDERS:
  - DUE 2026-03-24: Verify prep materials changed workflow behavior

KNOWLEDGE GRAPH:
  Nodes: 1535 | Intake: 0 | Queue: 0 pending
  Observations: 11 | Horizon unreviewed: 0

DEPENDENCIES:
  Awaiting approval:
  - ws: 8.19.0 → 8.20.0 (MINOR)
  - eslint: 9.39.4 → 10.1.0 (MAJOR)

ACTIVE THREADS:
  - Multi-Agent Phase 3 — trust calibration
  - Agent Infrastructure Health — 4 checks planned

ALERTS:
  Observations at threshold (11) — run /rethink

=== Orient complete. ===
```

</details>

<details>
<summary>Production ship output (multi-agent, extended)</summary>

```
=== SESSION CLOSE ===

Commits: 8 this session
Knowledge nodes: 1535
Queue: 0 pending
Observations: 11

Goals updated:
  - Open-source release: updated (v1.0.0 shipped)
  - Dep checker fix: closed
  - Infrastructure health: unchanged

Pipeline verification:
  No pipeline work this session.

Unresolved:
  - 11 observations pending (/rethink)

Last-session.md: written (14 lines)
Git: committed and pushed (e644ef4)
Bridge: posted

=== Ship complete. ===
```

</details>

See [`examples/real-world/`](examples/real-world/) for the full extended examples with commentary.

## Origin

These tools were extracted from a production environment where multiple AI agents coordinate on tasks where accuracy matters. When the cost of a false claim is real — knowledge management, client communication, financial operations — "I'm pretty sure I did that" isn't good enough.

The tracker-ledger-guard pattern emerged from the observation that AI agents are systematically overconfident about their own actions. They don't lie on purpose — they pattern-match "I did the thing" from training data and produce confident completions. The orient-guard-ship loop is mechanical enforcement against this structural tendency.

## License

MIT
