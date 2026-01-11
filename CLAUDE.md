# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code plugin marketplace providing PowerShell 7.x ports of Claude Code plugins for Windows users. Plugins run natively on Windows without requiring WSL.

## Plugin Architecture

The marketplace structure:
```
.claude-plugin/marketplace.json    # Marketplace manifest listing all plugins
plugins/<plugin-name>/
  .claude-plugin/plugin.json       # Plugin metadata
  commands/*.md                    # Slash commands (markdown with YAML frontmatter)
  hooks/hooks.json                 # Hook definitions
  hooks/*.ps1                      # PowerShell hook implementations
  scripts/*.ps1                    # Supporting PowerShell scripts
```

### Command Files

Commands are markdown files with YAML frontmatter. Key frontmatter fields:
- `description`: Command description shown in help
- `argument-hint`: Usage hint for arguments
- `allowed-tools`: Array of Bash patterns the command can execute
- `hide-from-slash-command-tool`: Whether to hide from tool listing

### Hooks

Hooks intercept Claude events. Defined in `hooks/hooks.json`:
```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "pwsh ... script.ps1" }] }]
  }
}
```

Hook scripts receive input via stdin, output JSON decisions (e.g., `{"decision": "block", "reason": "..."}`).

## Current Plugin: ralph-loop-ps

PowerShell port of the Ralph Loop iterative development technique. Uses a Stop hook to intercept exit and feed the same prompt back, creating self-referential loops.

Key files:
- `scripts/setup-ralph-loop.ps1` - Initializes loop state in `.claude/ralph-loop.local.md`
- `hooks/stop-hook.ps1` - Intercepts stop, checks completion promise, continues loop

State file format: Markdown with YAML frontmatter containing `iteration`, `max_iterations`, `completion_promise`.

## PowerShell Requirements

All scripts require PowerShell 7.x (`#Requires -Version 7.0`). Key porting patterns from Bash:

| Bash | PowerShell |
|------|------------|
| `#!/bin/bash` | `#Requires -Version 7.0` |
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` |
| `$(cat)` / stdin | `$input \| Out-String` |
| `jq` | `ConvertFrom-Json` / `ConvertTo-Json` |
| `sed`, `grep` | PowerShell regex, `Select-String` |

Scripts invoked with: `pwsh -NoProfile -ExecutionPolicy Bypass -File "script.ps1"`

## Upstream Tracking

This repo ports plugins from `anthropics/claude-plugins-official`. The ralph-loop-ps plugin is a 1:1 functional port of the original ralph-loop bash plugin.

A GitHub Actions workflow (`.github/workflows/watch-upstream.yml`) runs daily to detect changes in upstream plugins. When changes are detected, it creates an issue with the `upstream-sync` label detailing what needs to be ported.
