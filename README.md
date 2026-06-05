# dotfiles

Personal configuration for [Claude Code](https://claude.ai/code).

## Contents

| File | Purpose |
|------|---------|
| `.claude/CLAUDE.md` | Global instructions and preferences for Claude |
| `.claude/settings.json` | Claude Code settings (model, statusline, effort, etc.) |
| `.claude/statusline.sh` | Custom statusline script — shows model, branch, diff, usage stats |
| `.claude/skills/` | Custom slash command skills |
| `.claude/commands/` | Custom slash commands |

## Setup

```bash
gh repo clone Looty/dotfiles ~/dotfiles
bash ~/dotfiles/setup.sh
```

`setup.sh` creates symlinks from `~/.claude/` into this repo so edits are tracked automatically.
