#!/bin/bash
# Claude Masterplan — installer
# Copies skills and hooks into your .claude/ directory.
# Run from the claude-masterplan repo root.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect target — use the current working directory's .claude/
# unless we're inside the repo itself
if [ "$PWD" = "$SCRIPT_DIR" ]; then
    echo "Run this from your project directory, not from inside claude-masterplan."
    echo "Usage: /path/to/claude-masterplan/install.sh"
    exit 1
fi

echo "Installing claude-masterplan into $PWD/.claude/"

# Skills
mkdir -p .claude/skills/orient .claude/skills/ship
cp "$SCRIPT_DIR/skills/orient/SKILL.md" .claude/skills/orient/
cp "$SCRIPT_DIR/skills/ship/SKILL.md" .claude/skills/ship/
echo "  Copied skills: orient, ship"

# Hooks
mkdir -p .claude/hooks
cp "$SCRIPT_DIR/hooks/"*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
echo "  Copied hooks: $(ls "$SCRIPT_DIR/hooks/"*.sh | wc -l | tr -d ' ') files"

# Ledger directory
mkdir -p .claude/guard-hooks
echo "  Created ledger directory: .claude/guard-hooks/"

# Settings
if [ -f .claude/settings.json ]; then
    echo ""
    echo "  ⚠ .claude/settings.json already exists."
    echo "  Merge the hook wiring from $SCRIPT_DIR/settings.json manually."
    echo "  (We won't overwrite your existing settings.)"
else
    cp "$SCRIPT_DIR/settings.json" .claude/settings.json
    echo "  Copied settings.json"
fi

echo ""
echo "Done. Run 'orient' to start your first session."
