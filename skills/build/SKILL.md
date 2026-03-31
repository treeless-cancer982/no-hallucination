---
name: build
description: Pre-build investigation gate. Use before building new infrastructure, scripts, hooks, or features. Triggers on "/build", "/build [description]".
user-invocable: true
---

## Configuration

```
# Set to "true" to clear the build gate automatically (for testing)
AUTO_CLEAR=false
```

## EXECUTE NOW

**Target: $ARGUMENTS**

If no target provided: ask "What are you building or fixing?" and stop.

**INVARIANT: No Write or Edit tool calls until Phase 5.** Phases 1-4 are investigation only. Phase 5 requires explicit approval.

---

### Phase 1: Investigate

Read all relevant files. Run diagnostic commands. Understand the full current state.

1. Identify every file, config, script, hook related to the problem space
2. Read them — not skim, read
3. Check adjacent systems that interact with the problem area
4. Run diagnostic commands to understand current state
5. If something is "broken," reproduce the broken behavior with a command

Do NOT assume you know the architecture. Do NOT skip files. Do NOT start forming a solution yet.

---

### Phase 2: Diagnose

State the root cause or requirement in ONE sentence. Cite the specific evidence that confirms it.

**Hard gate:** If you cannot state BOTH, return to Phase 1:
1. The root cause in one sentence
2. The specific evidence — file content, command output, or documentation

---

### Phase 3: Audit

Before building anything new, check what already exists.

- Search for existing solutions in the codebase
- Check if the problem can be solved with a config change, CLI flag, or existing tool
- If adding a hook: is there an existing hook that could be extended instead?

**Key question:** Could this be solved WITHOUT building anything new?

---

### Phase 4: Propose

Present findings and plan in this format:

```
=== BUILD: [target] ===

INVESTIGATE:
  Read: [N] files
    - [path]: [one-line finding]
  Current state: [2-3 sentences]

DIAGNOSE:
  Root cause: [ONE sentence]
  Evidence: [specific citation]

AUDIT:
  Existing solutions: [what already exists]
  Solve without building? [yes/no — if yes, how]

PROPOSE:
  Plan: [2-3 sentences]
  Files to create: [list]
  Files to modify: [list]
  Verification: [command that proves it works]
  Risk: [what could go wrong]

=== Awaiting approval. "go" to build, or redirect. ===
```

Clear the build gate:
```bash
mkdir -p .claude/guard-hooks && touch .claude/guard-hooks/.build-gate-cleared
```

**STOP HERE. Do not proceed without explicit approval.**

---

### Phase 5: Build

Only after approval ("go", "approved", "do it", or equivalent).

1. Execute the plan — no scope creep
2. After each change, verify
3. Report before/after state

```
BUILD COMPLETE:
  Created: [files]
  Modified: [files]
  Verification:
    Before: [what the check showed]
    After: [what it shows now]
```

---

## Edge Cases

- **Trivial fix:** Say "Trivial fix — skipping full investigation" and proceed directly.
- **Already investigated:** Jump to Phase 4.
- **No build needed:** Propose the simpler solution instead.
