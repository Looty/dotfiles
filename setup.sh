#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine.
# Usage: bash setup.sh
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.claude

link() {
  local src="$DOTFILES_DIR/$1"
  local dst="$HOME/$1"
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  echo "  linked $dst"
}

echo "Linking ~/.claude files..."
link .claude/CLAUDE.md
link .claude/settings.json
link .claude/statusline.sh
link .claude/skills
link .claude/commands

echo "Done."
