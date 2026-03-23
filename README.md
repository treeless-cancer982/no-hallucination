# Claude Masterplan

**Stop your AI from hallucinating its own history.**

A session discipline kit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that keeps agents honest — at session start, during work, and at session close. Three tools, one loop.

## The Problem

AI agents hallucinate their own history. They orient from degraded conversation summaries, make confident claims about work they didn't verify, and write session summaries from memory instead of evidence. Across sessions, these small lies compound — Session N's hallucination becomes Session N+1's false premise.

> Models are faithful to their chain of thought only 25-41% of the time.
> — [arxiv 2507.11473](https://arxiv.org/abs/2507.11473)

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

## Install

```bash
git clone https://github.com/AlethiaQuizForge/claude-masterplan.git
cd claude-masterplan
```

### Full loop (recommended)

```bash
# Copy skills
mkdir -p .claude/skills
cp -r skills/orient skills/ship .claude/skills/

# Copy hooks
mkdir -p .claude/hooks
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh

# Merge settings.json into your .claude/settings.json
# (see settings.json for the exact hook wiring)
```

### Just the guards

```bash
mkdir -p .claude/hooks
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
# Merge settings.json
```

### Just the lifecycle (orient + ship)

```bash
mkdir -p .claude/skills
cp -r skills/orient skills/ship .claude/skills/
```

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

**Configurable:** Set paths for your continuity file, goals file, reminders file, and grounding files in `skills/orient/SKILL.md`.

**Extensible:** Add custom state collectors (dependency checks, test status, Docker health — whatever matters for your project).

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

**Key rules:**
- Every claim in the session summary comes from a command output (`git log`, `git status`)
- Files staged by name — never `git add -A`
- Idempotent — won't double-commit if run twice
- Goals file updated automatically (completed work moved out of active threads)

## The Guards

Seven hooks using the **tracker-ledger-guard** pattern:

1. **Trackers** watch what the agent actually does — which commands it runs, which files it searches, when it edits files. They write entries to ledger files.
2. **Guards** read the agent's final response and check its claims against the ledger. If the claims don't match the evidence, the response is blocked.

### Guards (Stop hooks)

| Hook | What it catches |
|------|----------------|
| **verify-guard** | "All tests pass" — without running any tests |
| **proof-guard** | "Fixed the bug" — without before/after evidence |
| **claim-guard** | "Doesn't exist" — without searching first |

### Trackers (PostToolUse hooks)

| Hook | What it records |
|------|----------------|
| **verify-tracker** | Verification commands (test runners, status checks) |
| **search-tracker** | Search commands (grep, glob, find) |
| **edit-timestamp** | When the first file edit happened |

### Gate (PreToolUse hook)

| Hook | What it enforces |
|------|-----------------|
| **build-gate** | Investigation before editing infrastructure files |

```
Agent runs: npm test              →  verify-tracker logs it
Agent says: "All tests pass"      →  verify-guard checks ledger ✓

Agent says: "Verified — all green" → verify-guard checks ledger ✗ (empty!)
                                   → BLOCKED: "Run the actual verification command"
```

## Real-World Example

This kit was extracted from a production system where two AI agents coordinate across sessions — a knowledge scribe and a messenger, maintaining a domain knowledge base. The skills are extended with domain-specific state collectors:

<details>
<summary>Production orient output (extended)</summary>

```
=== ORIENT — 2026-03-23 ===

CONTINUITY:
  Processed 12 clinical insights from DSM-5 pocket guide.
  Pipeline verification: all batches PASS. Graph fully connected.

UNRESOLVED (carried forward):
  - 3 insights need cross-domain connections
  - Dependency: ws 8.19.0 → 8.20.0 (MINOR, awaiting approval)

BRIDGE (unread):
  Hermes: "Signal trust fixed for two practitioners. Briefings will flow."

REMINDERS:
  - DUE 2026-03-24: Verify assessment prep changed clinical behavior

KNOWLEDGE GRAPH:
  Insights: 1535 | Intake: 0 | Queue: 0 pending
  Observations: 11 | Horizon unreviewed: 0

DEPENDENCIES:
  Awaiting approval:
  - ws: 8.19.0 → 8.20.0 (MINOR)
  - eslint: 9.39.4 → 10.1.0 (MAJOR)

ACTIVE THREADS:
  - Multi-Agent Phase 3 — Accountant Calibration
  - Continuity — PreCompact + PostCompact hooks shipped
  - Agent Infrastructure Health — 4 checks planned

ALERTS:
  Observations at threshold (11) — run /rethink

=== Orient complete. ===
```

</details>

<details>
<summary>Production ship output (extended)</summary>

```
=== SESSION CLOSE ===

Commits: 8 this session
KB: 1535 nodes
Queue: 0 pending
Observations: 11

Goals updated:
  - Open-Source Products: updated (ship skill released)
  - Dep checker fix: closed
  - Agent Infrastructure Health: unchanged

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

See the [`examples/real-world/`](examples/real-world/) directory for the full extended examples with commentary on how each customization point was used.

## Configuration

Both skills have a **Configuration** section at the top of their `SKILL.md` with paths you can customize:

**Orient:**
```
CONTINUITY_FILE=".claude/last-session.md"
GOALS_FILE=""
REMINDERS_FILE=""
GROUNDING_FILES=""
```

**Ship:**
```
CONTINUITY_FILE=".claude/last-session.md"
GOALS_FILE=""
PUSH_AFTER_COMMIT=true
```

**Hooks:** Set `GUARD_HOOKS_DIR` to change ledger location. Set `GUARD_HOOKS_SEARCH_SCOPES` for multi-directory search enforcement. See [hook configuration](hooks/) for details.

## Requirements

- Claude Code (any version with hooks and skills support)
- bash, jq (standard on macOS and Linux)
- git (for orient/ship state collection)

## Origin

These tools were extracted from a production environment where multiple AI agents coordinate on tasks where accuracy matters. When the cost of a false claim is real — knowledge management, client communication, financial operations — "I'm pretty sure I did that" isn't good enough.

The tracker-ledger-guard pattern emerged from the observation that AI agents are systematically overconfident about their own actions. They don't lie on purpose — they pattern-match "I did the thing" from training data and produce confident completions. The orient-guard-ship loop is mechanical enforcement against this structural tendency.

## License

MIT
