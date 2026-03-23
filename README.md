# no-hallucination

**Stop your AI from hallucinating its own history.**

The problem everyone has but nobody else is solving mechanically.

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

When a guard fires, Claude Code shows the block reason and the agent gets a second chance to produce evidence. No session stall — just enforced honesty.

## The Problem

AI agents hallucinate their own history. They make confident claims about work they didn't verify, write session summaries from memory instead of evidence, and orient from degraded conversation summaries. Across sessions, these small lies compound — Session N's hallucination becomes Session N+1's false premise.

> Models are faithful to their chain of thought only 25-41% of the time.
> — [Chain of Thought Monitorability (arxiv 2507.11473)](https://arxiv.org/abs/2507.11473)

## What's In The Box

### 9 hooks that catch your AI lying

Seven guard hooks using the **tracker-ledger-guard** pattern, plus two compaction hooks that protect context across long sessions.

**Trackers** watch what the agent does and write evidence to ledger files. **Guards** check the agent's claims against that evidence. If the claims don't match, the response is blocked.

| Hook | Type | What it does |
|------|------|-------------|
| **verify-guard** | Guard | Blocks "all tests pass" without running any tests |
| **proof-guard** | Guard | Blocks "fixed the bug" without before/after evidence |
| **claim-guard** | Guard | Blocks "doesn't exist" without searching first |
| **verify-tracker** | Tracker | Logs verification commands (test runners, status checks) |
| **search-tracker** | Tracker | Logs search commands (grep, glob, find) |
| **edit-timestamp** | Tracker | Records when the first file edit happened |
| **build-gate** | Gate | Requires investigation before editing infrastructure files |
| **pre-compact** | Compaction | Forces state persistence before context compression |
| **post-compact** | Compaction | Re-injects critical context after compression |

```
Stop hook fires
  │
  ├─ verify-guard: "Did you run ANY verification command?"
  │   └─ No → BLOCK (run the check first)
  │   └─ Yes → pass
  │
  ├─ proof-guard: "Did you check BEFORE and AFTER the edit?"
  │   └─ No before → BLOCK (show the broken state first)
  │   └─ No after  → BLOCK (verify the fix)
  │   └─ Both      → pass
  │
  └─ claim-guard: "Did you SEARCH before saying it doesn't exist?"
      └─ No → BLOCK (look before you speak)
      └─ Yes → allow
```

### 2 skills that close the loop

```
/orient (start) ──→ guard hooks (during) ──→ /ship (close)
      ↑                                           │
      └──────────── last-session.md ←──────────────┘
```

**`/orient`** — Structured session start. Reads the continuity file from the last `/ship`, collects live state (git, goals, reminders), presents a structured report. Evidence-based orientation, not conversation recall.

**`/ship`** — Session close. Writes a continuity file from `git log` and command outputs — never from conversation memory. Every claim traceable to a command. What it writes is what `/orient` reads next session.

The continuity file is the handshake. Ship writes truth → orient reads truth → the next session starts from evidence instead of hallucination.

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
  Recent: abc1234 Session close: rate limiter + pagination fix

ALERTS:
  None.

=== Orient complete. ===
```

```
> /ship

=== SESSION CLOSE ===

Commits: 3 this session

Unresolved:
  - Integration tests for rate limiter not written
  - docs/api.md needs rate limit headers documented

Context for next session:
  - Chose sliding window rate limiter over fixed window — see commit notes

Continuity: written (14 lines)
Git: committed and pushed (abc1234)

=== Ship complete. ===
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (any version with hooks and skills support)
- bash, jq (standard on macOS and Linux)
- git

## Install

### Quick install

```bash
git clone https://github.com/AlethiaQuizForge/no-hallucination.git
cd your-project
/path/to/no-hallucination/install.sh         # minimal orient
/path/to/no-hallucination/install.sh --full  # production-grade orient
```

The installer checks for jq and git, copies everything, and creates the ledger directory. If you already have a `settings.json`, it won't overwrite — you'll merge manually.

### Manual install

```bash
git clone https://github.com/AlethiaQuizForge/no-hallucination.git
```

**Full setup** (recommended):
```bash
mkdir -p .claude/skills .claude/hooks .claude/guard-hooks
cp -r skills/orient skills/ship .claude/skills/   # or orient-full for production
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
# Merge settings.json into your .claude/settings.json
```

**Just the guards** (hooks only, no skills):
```bash
mkdir -p .claude/hooks .claude/guard-hooks
cp hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

## Configuration

### Skills

Both skills have a **Configuration** section at the top of their SKILL.md:

**Orient** (`skills/orient/SKILL.md` or `skills/orient-full/SKILL.md`):
```
CONTINUITY_FILE=".claude/last-session.md"   # Written by /ship
GOALS_FILE=""                                # e.g., "goals.md"
REMINDERS_FILE=""                            # e.g., ".claude/reminders.md"
GROUNDING_FILES=""                           # Files to read silently at start
```

**Ship** (`skills/ship/SKILL.md`):
```
CONTINUITY_FILE=".claude/last-session.md"
GOALS_FILE=""
PUSH_AFTER_COMMIT=true
COMMIT_PREFIX="Session close:"               # Also used for idempotency check
```

**orient-full** ships with commented-out extension points for dependency checks, test suite health, build status, service health, and custom metrics. Uncomment what you need.

### Hooks

Set `GUARD_HOOKS_DIR` to change where ledger files are stored (default: `.claude/guard-hooks/`). Set `GUARD_HOOKS_SEARCH_SCOPES` for multi-directory search enforcement. Each guard has a `TRIGGERS` variable near the top — add or remove phrases to match your workflow.

## Orient: Minimal vs Full

| | orient (minimal) | orient-full (production) |
|---|---|---|
| Continuity file | yes | yes |
| Git state | yes | yes |
| Goals tracking | optional | yes (configured) |
| Reminders | optional | yes (configured) |
| Dependency checks | no | extension point |
| Test suite health | no | extension point |
| Build / CI status | no | extension point |
| Service health | no | extension point |
| Custom metrics | no | extension point |

Use minimal to start. Switch to full when you want more from your session start.

## Real-World Example

This kit was extracted from a production system where two AI agents coordinate across sessions. The orient and ship skills are extended with inter-agent messaging, dependency monitoring, knowledge graph metrics, and processing pipeline verification:

<details>
<summary>Production orient output (multi-agent, extended)</summary>

```
=== ORIENT — 2026-03-23 ===

CONTINUITY:
  Processed 12 source documents into knowledge graph.
  Pipeline verification: all batches PASS.

UNRESOLVED:
  - 3 items need cross-domain connections
  - ws 8.19.0 → 8.20.0 (MINOR, awaiting approval)

BRIDGE (unread):
  Agent-2: "Config fix deployed. Service restored."

REMINDERS:
  - DUE 2026-03-24: Verify prep materials changed workflow

KNOWLEDGE GRAPH:
  Nodes: 1535 | Intake: 0 | Queue: 0

DEPENDENCIES:
  - ws: 8.19.0 → 8.20.0 (MINOR)
  - eslint: 9.39.4 → 10.1.0 (MAJOR)

ACTIVE THREADS:
  - Multi-agent trust calibration
  - Infrastructure health — 4 checks planned

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
Observations: 11

Goals updated:
  - Open-source release: shipped (v1.0.0)
  - Dep checker: closed (re-scan after auto-update)

Unresolved:
  - 11 observations pending

Context for next session:
  - Bundled orient+guards+ship into single product
  - Guard hooks are the lead value — skills are optional lifecycle
  - Name discussion ongoing (peer agents reviewing)

Last-session.md: written (18 lines)
Git: committed and pushed (e644ef4)
Bridge: posted

=== Ship complete. ===
```

</details>

## Origin

These tools were extracted from a production environment where multiple AI agents coordinate on tasks where accuracy matters. When the cost of a false claim is real — knowledge management, client communication, financial operations — "I'm pretty sure I did that" isn't good enough.

The tracker-ledger-guard pattern emerged from the observation that AI agents are systematically overconfident about their own actions. They don't lie on purpose — they pattern-match "I did the thing" from training data and produce confident completions. The orient-guard-ship loop is mechanical enforcement against this structural tendency.

## License

MIT
