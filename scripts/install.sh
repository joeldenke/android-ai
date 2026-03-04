#!/usr/bin/env bash
# install.sh — install Android AI rules/agents/skills into your Android project
#
# Usage (run from your Android project root):
#   bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) <tool>
#
# Examples:
#   bash <(curl -fsSL .../install.sh) claude    # Claude Code
#   bash <(curl -fsSL .../install.sh) cursor    # Cursor
#   bash <(curl -fsSL .../install.sh) copilot   # GitHub Copilot
#   bash <(curl -fsSL .../install.sh) codex     # Codex CLI
#   bash <(curl -fsSL .../install.sh) gemini    # Gemini CLI / AI Studio
#   bash <(curl -fsSL .../install.sh) windsurf  # Windsurf
#   bash <(curl -fsSL .../install.sh) all       # Every tool

set -euo pipefail

REPO="https://github.com/joeldenke/android-ai"
TOOL="${1:-}"

print_help() {
  cat <<EOF
install.sh — Android AI plugin installer

Usage:
  bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) <tool>

Tools:
  claude    Claude Code — agents/ skills/ hooks/ + .claude/ + CLAUDE.md
            (prefer the plugin marketplace when inside Claude Code:
             /plugin marketplace add joeldenke/android-ai && /plugin install android-ai)
  cursor    Cursor       — .cursor/rules/ (15 MDC rules, auto-loaded on every chat)
  copilot   Copilot      — .github/copilot-instructions.md (all skills merged as workspace instructions)
  codex     Codex CLI    — AGENTS.md (agent index read automatically by Codex)
  gemini    Gemini CLI   — skills/ (reference inline: gemini "\$(cat skills/new-feature.md)" "...")
  windsurf  Windsurf     — .windsurfrules (coding standards + key skills, auto-loaded)
  all       Everything above

What each tool gets:
  Capability                  claude  cursor  copilot  codex  gemini  windsurf
  Skills (rules / commands)     ✓       ✓       ✓        -      ✓       ✓
  Agents (specialist delegation) ✓      -       -        ✓      -       -
  Hooks (lifecycle automation)   ✓      -       -        -      -       -
EOF
}

if [[ -z "$TOOL" || "$TOOL" == "--help" || "$TOOL" == "-h" || "$TOOL" == "help" ]]; then
  print_help
  [[ -z "$TOOL" ]] && exit 1 || exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Cloning android-ai..."
git clone --depth=1 --quiet "$REPO" "$TMP/android-ai"
SRC="$TMP/android-ai"

install_claude() {
  echo "Installing for Claude Code..."
  # Copy real content from root dirs (source of truth)
  cp -r "$SRC/agents"  ./agents
  cp -r "$SRC/skills"  ./skills
  cp -r "$SRC/hooks"   ./hooks
  # .claude/ — local Claude Code config pointing at root dirs
  mkdir -p .claude
  [[ -L .claude/agents ]] || ln -s ../agents .claude/agents
  [[ -L .claude/skills ]] || ln -s ../skills .claude/skills
  [[ -L .claude/hooks  ]] || ln -s ../hooks  .claude/hooks
  [[ -f .claude/settings.json ]] || cp "$SRC/.claude/settings.json" .claude/settings.json
  [[ -f CLAUDE.md ]] || cp "$SRC/CLAUDE.md" ./CLAUDE.md
  echo "  ✓ agents/, skills/, hooks/"
  echo "  ✓ .claude/ (settings.json + symlinks)"
  echo "  ✓ CLAUDE.md"
}

install_cursor() {
  echo "Installing for Cursor..."
  mkdir -p .cursor/rules
  cp "$SRC/.cursor/rules/"*.mdc .cursor/rules/
  echo "  ✓ .cursor/rules/ ($(ls "$SRC/.cursor/rules/"*.mdc | wc -l | tr -d ' ') rules)"
}

install_copilot() {
  echo "Installing for GitHub Copilot..."
  mkdir -p .github
  {
    echo "# Android AI — Copilot Instructions"
    echo "# Generated from https://github.com/joeldenke/android-ai"
    echo ""
    awk '/^## Coding Standards/,/^## Key References/' "$SRC/CLAUDE.md" | head -n -1
    echo ""
    for skill_file in "$SRC/skills/"*.md; do
      echo "---"
      echo ""
      awk '/^---$/{if(fm<2){fm++;next}} fm==2&&/^When the user runs /{next} fm==2{print}' "$skill_file"
      echo ""
    done
  } > .github/copilot-instructions.md
  echo "  ✓ .github/copilot-instructions.md"
}

install_codex() {
  echo "Installing for Codex CLI..."
  cp "$SRC/AGENTS.md" ./AGENTS.md
  echo "  ✓ AGENTS.md"
}

install_gemini() {
  echo "Installing for Gemini CLI..."
  cp -r "$SRC/skills" ./skills
  echo "  ✓ skills/ ($(ls "$SRC/skills/"*.md | wc -l | tr -d ' ') skill files)"
  echo "  Usage: gemini \"\$(cat skills/new-feature.md)\" \"Scaffold a UserProfile feature\""
}

install_windsurf() {
  echo "Installing for Windsurf..."
  cp "$SRC/.windsurfrules" ./.windsurfrules
  echo "  ✓ .windsurfrules"
}

case "$TOOL" in
  claude)   install_claude ;;
  cursor)   install_cursor ;;
  copilot)  install_copilot ;;
  codex)    install_codex ;;
  gemini)   install_gemini ;;
  windsurf) install_windsurf ;;
  all)
    install_claude
    install_cursor
    install_copilot
    install_codex
    install_gemini
    install_windsurf
    ;;
  *)
    echo "error: unknown tool '$TOOL'"
    echo ""
    print_help
    exit 1
    ;;
esac

echo ""
echo "Done. android-ai installed for: $TOOL"
