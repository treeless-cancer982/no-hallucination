#!/bin/bash
# no-hallucination — installer
# Copies skills and hooks into your .claude/ directory.
# Run from your project directory (not from inside this repo).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect target
if [ "$PWD" = "$SCRIPT_DIR" ]; then
    echo "Run this from your project directory, not from inside the repo."
    echo ""
    echo "Usage:"
    echo "  cd your-project"
    echo "  $0"
    exit 1
fi

# Check requirements
MISSING=""
command -v bash >/dev/null 2>&1 || MISSING="$MISSING bash"
command -v jq >/dev/null 2>&1 || MISSING="$MISSING jq"
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"

if [ -n "$MISSING" ]; then
    echo "Missing required tools:$MISSING"
    echo ""
    echo "Install with:"
    command -v brew >/dev/null 2>&1 && echo "  brew install$MISSING"
    command -v apt-get >/dev/null 2>&1 && echo "  sudo apt-get install$MISSING"
    exit 1
fi

echo "Installing no-hallucination into $PWD/.claude/"
echo ""

# Choose orient variant
if [ "$1" = "--full" ]; then
    ORIENT_SRC="$SCRIPT_DIR/skills/orient-full"
    echo "  Using orient-full (production-grade with extension points)"
else
    ORIENT_SRC="$SCRIPT_DIR/skills/orient"
    echo "  Using orient (minimal — pass --full for production-grade variant)"
fi

# Skills
mkdir -p .claude/skills/orient .claude/skills/ship .claude/skills/build
cp "$ORIENT_SRC/SKILL.md" .claude/skills/orient/
cp "$SCRIPT_DIR/skills/ship/SKILL.md" .claude/skills/ship/
cp "$SCRIPT_DIR/skills/build/SKILL.md" .claude/skills/build/
echo "  Copied skills: orient, ship, build"

# Hooks
mkdir -p .claude/hooks
cp "$SCRIPT_DIR/hooks/"*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
HOOK_COUNT=$(ls "$SCRIPT_DIR/hooks/"*.sh | wc -l | tr -d ' ')
echo "  Copied hooks: $HOOK_COUNT files (9 guards/trackers + 2 compaction)"

# Scripts
mkdir -p scripts
cp "$SCRIPT_DIR/scripts/"*.sh scripts/ 2>/dev/null
chmod +x scripts/*.sh 2>/dev/null
echo "  Copied scripts: hook-health.sh"

# Ledger directory
mkdir -p .claude/guard-hooks
echo "  Created ledger directory: .claude/guard-hooks/"

# Settings
if [ -f .claude/settings.json ]; then
    echo ""
    echo "  .claude/settings.json already exists — not overwriting."
    echo "  Merge the hook wiring from $SCRIPT_DIR/settings.json manually."
    echo ""
    echo "  Quick check — paste this into your settings.json hooks section:"
    echo "  (see $SCRIPT_DIR/settings.json for the full structure)"
else
    cp "$SCRIPT_DIR/settings.json" .claude/settings.json
    echo "  Copied settings.json (hook wiring)"
fi

echo ""
echo "Done. Say 'orient' to start your first session."
echo ""
echo "Next steps:"
echo "  1. Edit .claude/skills/orient/SKILL.md — set your file paths"
echo "  2. Edit .claude/skills/ship/SKILL.md — set your file paths"
echo "  3. If you merged settings.json, verify hooks fire: say 'test' then claim 'all tests pass'"
